//
//  NISRequestDispatcher.swift
//  NIS
//
//  Created by Andrew Matsota on 07.04.2026.
//

import Foundation

// MARK: - Dispatcher

/// Coordinates the full request execution pipeline for the SDK.
///
/// `NISRequestDispatcher` is the central orchestration object responsible for
/// preparing requests, executing transport calls, validating responses, applying
/// retry rules, preventing duplicate in-flight work, and transforming raw payloads
/// into strongly typed results.
///
/// ## Execution pipeline
/// A request goes through the following stages:
/// 1. The original `URLRequest` is adapted by `adapter`, if configured.
/// 2. The request may be deduplicated using `duplicateStrategy`.
/// 3. The request is executed through the injected `session`.
/// 4. The raw response is validated against `validStatusCodes`.
/// 5. If execution fails, the error is normalized and passed through `errorInterceptor`.
/// 6. The retry policy is evaluated by `retryStrategy`.
/// 7. On success, raw payload is transformed into a consumer-defined value.
/// 8. Successful payloads are passed to `responseAnalyzer`.
///
/// ## Design goals
/// - async-first API based on Swift structured concurrency
/// - reusable in both SDK and app environments
/// - composable request/response pipeline
/// - centralized and consistent error handling
/// - deterministic duplicate request coalescing
///
/// ## Thread safety
/// The dispatcher is marked as `@unchecked Sendable` because it may be shared
/// across concurrency domains, while some injected strategy objects may not
/// themselves be statically verified as `Sendable`.
///
/// Consumers are responsible for ensuring that injected collaborators are safe
/// to use from concurrent contexts.
///
/// ## Duplicate request behavior
/// When `duplicateStrategy` returns the same hash for multiple in-flight requests,
/// only one underlying network task is executed. All concurrent callers receive
/// the same resulting payload. Responses returned to joined callers are marked
/// with `isDuplicate == true`.
///
/// ## Error behavior
/// The dispatcher always returns `NISResponse<Value>` rather than throwing from
/// the public request APIs. This keeps transport, validation, and decoding failures
/// inside a unified response model.
///
/// ## Example
/// ```swift
/// let dispatcher = NISRequestDispatcher()
/// dispatcher.requestAdapter = AuthAdapter()
/// dispatcher.retryStrategy = DefaultRetrier()
///
/// let response: NISResponse<UserDTO> = await dispatcher.request(request)
/// ```
public final class NISRequestDispatcher: @unchecked Sendable {

    // MARK: - Public Dependencies

    /// Optional request adaptation pipeline executed before transport begins.
    ///
    /// Typical use cases:
    /// - authentication headers
    /// - locale or device metadata injection
    /// - request signing
    /// - dynamic request mutation based on runtime state
    ///
    /// If `noOp`, the original request is executed unchanged.
    public var requestAdapter: NISRequestAdaptable = .noOp

    /// Optional side-effect analyzer invoked after a successful response
    /// has been received and transformed.
    ///
    /// Typical use cases:
    /// - logging
    /// - analytics
    /// - metrics
    /// - diagnostics
    ///
    /// Analyzer failures are not surfaced because this contract is non-throwing.
    public var responseAnalyzer: NISResponseDataAnalyzable = .noOp

    /// Optional strategy used to identify equivalent in-flight requests.
    ///
    /// When configured, identical requests may share a single transport operation.
    /// Defaults to `.noOp`, meaning every request is executed independently.
    public var duplicateStrategy: NISDuplicateIdentifying = .noOp
    
    /// Optional retry strategy evaluated after transport or validation failure.
    ///
    /// If `noOp`, failures are returned immediately without retry attempts.
    public var retryStrategy: NISRequestRetryable = .noOp

    /// Error transformation pipeline executed after a request failure has been
    /// normalized into `NISError`, but before retry evaluation or final delivery.
    ///
    /// Defaults to `.noOp`, meaning the error is forwarded unchanged.
    public var errorInterceptor: NISDispatcherErrorInterceptable = .noOp

    /// Optional backend error parser used when an HTTP response fails validation.
    ///
    /// Parsed errors are attached to `.invalidStatusCode` in order to preserve
    /// server-specific failure context.
    public var errorParser: NISErrorParsable?
    
    /// Provides reuse policy for each request.
    ///
    /// ## Purpose
    /// Acts as a single decision point for enabling short-lived response reuse.
    ///
    /// ## Default behavior
    /// By default, a no-op implementation is used, meaning:
    /// - response reuse is disabled
    /// - all requests are executed normally
    ///
    /// ## Customization
    /// Can be replaced with a custom implementation to enable dynamic behavior,
    /// such as:
    /// - endpoint-based rules
    /// - remote configuration
    /// - feature flags
    ///
    /// ## Thread safety
    /// The implementation must be thread-safe, as it may be called concurrently.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.responseReusePolicy = RemoteConfigReuseDecider(...)
    /// ```
    public var responseReusePolicy: NISRecentResponseReusable = .noOp

    /// Allowed HTTP status code range for a response to be treated as successful.
    ///
    /// Defaults to `200...299`.
    ///
    /// Set to `nil` to disable status-code validation entirely.
    public var validStatusCodes: ClosedRange<Int>? = 200...299

    // MARK: - Private

    /// Transport layer used to execute prepared requests.
    ///
    /// Injected as a protocol to support custom sessions, SDK integration,
    /// testing, and transport substitution.
    private let session: AnyNISURLSession

    /// Internal actor-based store that coalesces identical in-flight requests.
    private let inflightRequestStore = InflightRequestStore()

    // MARK: - Init

    /// Creates a dispatcher with the provided session implementation.
    ///
    /// - Parameter session:
    ///   Transport implementation used to execute requests.
    ///   Defaults to `NISURLSession()`.
    public init(session: AnyNISURLSession = NISURLSession()) {
        self.session = session
    }

    // MARK: - Public API

    /// Executes the provided request and transforms raw response data into `Value`.
    ///
    /// This is the most flexible entry point of the dispatcher. Callers provide
    /// a custom transformation closure that maps raw payload bytes into any output type.
    ///
    /// ## Behavior
    /// - request adaptation is applied before execution
    /// - duplicate in-flight requests may be coalesced
    /// - transport and validation errors are normalized into `NISError`
    /// - decoding or transformation failures are returned as `.decoding`
    /// - the method never throws; failures are wrapped in `NISResponse`
    ///
    /// ## Duplicate responses
    /// If the request joined an already running equivalent operation, the returned
    /// response is marked as duplicate via `response.isDuplicate == true`.
    ///
    /// - Parameters:
    ///   - originalRequest: The request created by the caller.
    ///   - transform:
    ///     A closure that converts raw `Data?` into the desired output value.
    ///     This closure is invoked only after transport and response validation succeed.
    ///
    /// - Returns:
    ///   A response wrapping either the transformed value or a normalized failure.
    public func request<Value>(
        _ originalRequest: URLRequest,
        transform: @escaping (Data?) throws -> Value
    ) async -> NISResponse<Value> {
        do {
            let adaptedRequest = try await adaptRequest(originalRequest)

            try Task.checkCancellation()
            
            let payloadResult: Result<NISResponseData, NISError>
            let isDuplicate: Bool

            if let uniqueHash = duplicateStrategy.uniqueHash(for: adaptedRequest) {
                let operation: @Sendable () async -> Result<NISResponseData, NISError> = { [self, adaptedRequest] in
                    await self.executeRequest(adaptedRequest, retryCount: 0)
                }
                
                let stored = await inflightRequestStore.value(
                    for: uniqueHash,
                    policy: responseReusePolicy.policy(for: adaptedRequest),
                    operation: operation
                )
                payloadResult = stored.result
                isDuplicate = stored.isDuplicate
            } else {
                payloadResult = await executeRequest(adaptedRequest, retryCount: 0)
                isDuplicate = false
            }

            try Task.checkCancellation()
            
            switch payloadResult {
            case .success(let responseData):
                do {
                    let value = try transform(responseData.data)
                    responseAnalyzer.analyze(responseData: responseData)

                    var response = NISResponse(success: value, data: responseData)
                    if isDuplicate { response.setIsDuplicate() }
                    
                    return response
                } catch {
                    let nisError = NISError.decoding(error)
                    var response = NISResponse<Value>(
                        result: .failure(nisError),
                        data: responseData
                    )

                    if isDuplicate {
                        response.setIsDuplicate()
                    }

                    return response
                }

            case .failure(let error):
                var response = NISResponse<Value>(
                    result: .failure(error),
                    data: NISResponseData(
                        request: adaptedRequest,
                        data: nil,
                        response: nil
                    )
                )

                if isDuplicate {
                    response.setIsDuplicate()
                }

                return response
            }
        } catch {
            return NISResponse<Value>(
                error: normalize(error),
                data: NISResponseData(
                    request: originalRequest,
                    data: nil,
                    response: nil
                )
            )
        }
    }

    /// Executes the provided request and decodes the response body into a `Decodable` value.
    ///
    /// This is a convenience overload over `request(_:transform:)` for JSON-based APIs
    /// or any payloads supported by the provided `JSONDecoder`.
    ///
    /// ## Failure conditions
    /// - `NISError.emptyResponse` if the response body is missing
    /// - `NISError.decoding` if decoding fails
    /// - any normalized transport or validation error produced earlier in the pipeline
    ///
    /// - Parameters:
    ///   - originalRequest: The request created by the caller.
    ///   - type: The decodable output type. Defaults to `Value.self`.
    ///   - decoder: Decoder used to deserialize the payload. Defaults to a new `JSONDecoder`.
    ///
    /// - Returns:
    ///   A typed response containing either the decoded model or a normalized failure.
    public func request<Value: Decodable>(
        _ originalRequest: URLRequest,
        as type: Value.Type = Value.self,
        decoder: JSONDecoder = .nis
    ) async -> NISResponse<Value> {
        await request(originalRequest) { data in
            guard let data else { throw NISError.emptyResponse }
            return try decoder.decode(Value.self, from: data)
        }
    }
}

// MARK: - Private Helpers

private extension NISRequestDispatcher {

    /// Applies the configured request adapter chain to the provided request.
    ///
    /// - Parameter request: Original caller-provided request.
    /// - Returns: Adapted request, or the original request when no adapter is configured.
    /// - Throws: Any error produced by the adapter pipeline.
    func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
        try await requestAdapter.adapt(request: request)
    }

    /// Executes a prepared request, validates the response, and evaluates retry rules.
    ///
    /// This method performs the low-level dispatch loop used by the public APIs.
    /// It is responsible for:
    /// - calling the transport layer
    /// - building `NISResponseData`
    /// - validating response status codes
    /// - normalizing and intercepting errors
    /// - applying retry delay when requested
    ///
    /// - Parameters:
    ///   - request: Fully prepared request ready for transport execution.
    ///   - retryCount: Current retry attempt number.
    ///
    /// - Returns:
    ///   A success result containing raw response data, or a normalized failure.
    func executeRequest(
        _ request: URLRequest,
        retryCount: Int
    ) async -> Result<NISResponseData, NISError> {
        do {
            try Task.checkCancellation()
            
            let (data, response) = try await session.data(for: request)
            let responseData = NISResponseData(
                request: request,
                data: data,
                response: response
            )
            
            try validate(responseData: responseData)

            return .success(responseData)
        } catch {
            let normalized = normalize(error)
            
            if case .cancelled = normalized {
                return .failure(.cancelled)
            }
            
            let interceptedError = await errorInterceptor.interceptError(
                error: normalized,
                request: request,
                response: nil,
                data: nil
            )
        
            let responseData = NISResponseData(
                request: request,
                data: nil,
                response: nil
            )
            
            if Task.isCancelled { return .failure(.cancelled) }
            
            let decision = await retryStrategy.shouldRetry(
                request: request,
                error: interceptedError,
                responseData: responseData,
                retryCount: retryCount
            )

            guard decision.shouldRetry else { return .failure(interceptedError) }

            if decision.delay > 0 {
                if Task.isCancelled { return .failure(.cancelled) }
                do { try await Task.sleep(nanoseconds: UInt64(decision.delay * 1_000_000_000)) }
                catch { return .failure(.cancelled) }
            }

            if Task.isCancelled { return .failure(.cancelled) }
            return await executeRequest(request, retryCount: retryCount + 1)
        }
    }

    /// Validates raw response data against dispatcher rules.
    ///
    /// Validation currently ensures:
    /// - the response can be represented as `HTTPURLResponse`
    /// - the response status code falls within `validStatusCodes`, when configured
    ///
    /// If status validation fails, the optional `errorParser` is used to extract
    /// backend-specific error information and attach it to the resulting `NISError`.
    ///
    /// - Parameter responseData: Raw response data to validate.
    /// - Throws: `NISError.invalidResponse` or `NISError.invalidStatusCode`.
    func validate(responseData: NISResponseData) throws {
        guard let httpResponse = responseData.httpResponse else { throw NISError.invalidResponse }
        guard let validStatusCodes else { return }

        guard validStatusCodes.contains(httpResponse.statusCode) else {
            let parsedError = errorParser?.parse(
                data: responseData.data,
                response: httpResponse
            )

            throw NISError.invalidStatusCode(
                httpResponse.statusCode,
                responseData.data,
                parsedError.map(NISUnderlyingError.init)
            )
        }
    }

    /// Converts arbitrary errors produced by transport or local processing into `NISError`.
    ///
    /// Normalization rules:
    /// - preserves `NISError` as-is
    /// - maps `CancellationError` and `URLError.cancelled` to `.cancelled`
    /// - wraps all other errors into `.transport`
    ///
    /// - Parameter error: Source error to normalize.
    /// - Returns: Normalized dispatcher error.
    func normalize(_ error: Error) -> NISError {
        if let nisError = error as? NISError { return nisError }
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError, urlError.code == .cancelled { return .cancelled }
        return .transport(.init(error))
    }
}
