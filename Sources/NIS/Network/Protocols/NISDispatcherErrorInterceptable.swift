//
//  AnyNISDispatcherErrorInterceptor.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A component responsible for transforming or enriching errors produced by the dispatcher.
///
/// `NISDispatcherErrorInterceptable` operates after a request has failed but before
/// the error is returned to the caller or evaluated for retry.
///
/// - Responsibilities:
///   - normalize errors across different layers (transport, decoding, backend)
///   - map backend-specific errors into domain-level errors
///   - enrich errors with additional context (headers, payload, request info)
///
/// - Execution:
///   Interceptors are executed sequentially when composed.
///   Each interceptor receives the result of the previous transformation.
///
/// - Important:
///   Implementations should be pure transformations and must not trigger side effects
///   such as starting new requests.
///
/// - Note:
///   This stage is part of the error handling pipeline and may affect retry decisions.
public protocol NISDispatcherErrorInterceptable {
    
    /// Transforms the provided error.
    ///
    /// - Parameters:
    ///   - error: The current error state.
    ///   - request: The original request that failed.
    ///   - response: The HTTP response, if available.
    ///   - data: The raw response payload, if available.
    /// - Returns: A transformed error.
    func interceptError(
        error: NISError,
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?
    ) async -> NISError
}

public extension NISDispatcherErrorInterceptable {

    /// Converts the interceptor into a composable pipeline.
    ///
    /// This method allows chaining multiple interceptors into a single
    /// sequential error-processing pipeline.
    ///
    /// - Behavior:
    ///   - Returns self if already composed
    ///   - Otherwise wraps into `NISErrorInterceptorComposer`
    ///
    /// - Execution:
    ///   Interceptors will be executed in order, each receiving the transformed
    ///   error from the previous step.
    ///
    /// - Example:
    /// ```swift
    /// dispatcher.errorInterceptor = CancellationInterceptor()
    ///     .asComposer()
    ///     .appending(BackendMappingInterceptor())
    /// ```
    ///
    /// - Returns: A composer containing the current interceptor.
    func asComposer() -> NISErrorInterceptorComposer {
        if let composer = self as? NISErrorInterceptorComposer {
            return composer
        }
        return NISErrorInterceptorComposer([self])
    }
}
