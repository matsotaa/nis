//
//  NISRequestDispatcher+Extensions.swift
//  NIS
//
//  Created by Andrew Matsota on 20.04.2026.
//

import Foundation

public extension NISRequestDispatcher {
    
    /// Executes a request using the dispatcher's async pipeline and delivers the
    /// final result through a legacy completion-based callback.
    ///
    /// `uncheckedRequest` exists as a compatibility bridge for codebases that
    /// still rely on completion handlers instead of adopting the dispatcher's
    /// async API directly.
    ///
    /// ## Purpose
    /// This method allows consumers to use the SDK in environments where:
    /// - completion-based networking is still preferred
    /// - migration to async/await is incremental
    /// - existing architecture expects callback delivery
    ///
    /// Internally, the dispatcher still executes the request through its modern
    /// async pipeline. This API only changes the delivery style.
    ///
    /// ## Execution flow
    /// 1. A legacy request call is made with a completion closure.
    /// 2. The SDK starts an internal `Task`.
    /// 3. The request is executed through the dispatcher's async request API.
    /// 4. The final `NISResponse<T>` is bridged into callback-based delivery.
    /// 5. The completion is invoked on `callbackQueue`.
    ///
    /// ## Delivery guarantees
    /// - the underlying request still uses the dispatcher pipeline
    /// - request adaptation, retry logic, duplicate handling, validation,
    ///   interception, and decoding all behave the same as in async APIs
    /// - completion delivery is dispatched onto `callbackQueue`
    ///
    /// ## Cancellation
    /// The returned `NISCancellable` cancels the internal bridging task.
    ///
    /// If cancellation happens before completion delivery, the completion handler is not invoked.
    ///
    /// ## Important
    /// This method is intentionally named `uncheckedRequest` because it relies on
    /// an internal unchecked bridge (`NISUncheckedSendableBox`) to move values
    /// through concurrency boundaries required by the legacy callback model.
    ///
    /// Consumers should understand that:
    /// - this is a compatibility API
    /// - the SDK takes responsibility for the internal bridge
    /// - the preferred modern API remains the async `request(...)` methods
    ///
    /// ## Threading
    /// The completion handler is called on the provided `callbackQueue`.
    ///
    /// This is especially useful for UI-driven code where consumers want to
    /// receive the result on `.main`.
    ///
    /// ## Safety notes
    /// This API is safe for normal legacy usage, but it should not be interpreted
    /// as a replacement for Swift's strict concurrency guarantees.
    ///
    /// The internal unchecked bridge is tightly scoped and used only to support
    /// callback-style delivery. It should not be treated as a general concurrency
    /// model.
    ///
    /// ## Recommended usage
    /// Prefer the async API when possible:
    ///
    /// ```swift
    /// let response: NISResponse<UserDTO> = await dispatcher.request(request)
    /// ```
    ///
    /// Use `uncheckedRequest` only when integrating with existing callback-based
    /// application code.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.uncheckedRequest(
    ///     request: request,
    ///     of: UserDTO.self,
    ///     callbackQueue: .main
    /// ) { response in
    ///     switch response.result {
    ///     case .success(let user):
    ///         print(user)
    ///     case .failure(let error):
    ///         print(error)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - urlRequest: Original request to execute.
    ///   - type: Expected decoded response type.
    ///   - decoder: Decoder used to deserialize response data.
    ///   - callbackQueue: Queue on which the completion callback is delivered.
    ///     Defaults to `.main`.
    ///   - completion: Legacy completion callback receiving the final `NISResponse<T>`.
    ///
    /// - Returns:
    ///   A cancellable handle for the internal bridging task.
    @discardableResult
    func uncheckedRequest<T: Decodable>(
        request urlRequest: URLRequest,
        of type: T.Type = T.self,
        decoder: JSONDecoder = .nis,
        callbackQueue: DispatchQueue? = .main,
        completion: @escaping (NISResponse<T>) -> Void
    ) -> NISCancellable {
        let completionBox = NISUncheckedSendableBox(completion)
        
        let task = Task { [self] in
            let response = await request(urlRequest, as: type, decoder: decoder)
            guard !Task.isCancelled else { return }
            
            let responseBox = NISUncheckedSendableBox(response)
            
            if let callbackQueue {
                callbackQueue.async { completionBox.value(responseBox.value) }
            } else {
                completionBox.value(responseBox.value)
            }
        }
        return NISRequestHandler(task: task)
    }
    
    /// Executes a request and ignores the decoded response body,
    /// returning only success or failure.
    ///
    /// This is a convenience overload over the generic `uncheckedRequest`
    /// that maps any successful response to `Void`.
    ///
    /// ## Behavior
    /// - the request is executed using the full dispatcher pipeline
    /// - the response is decoded as `NISEmptyResult`
    /// - the decoded value is discarded
    /// - completion receives `NISResponse<Void>`
    ///
    /// ## Use cases
    /// - endpoints where response body is not needed
    /// - fire-and-forget style requests with confirmation
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.uncheckedRequest(request: request) { response in
    ///     switch response.result {
    ///     case .success:
    ///         print("done")
    ///     case .failure(let error):
    ///         print(error)
    ///     }
    /// }
    /// ```
    @discardableResult
    func uncheckedRequest(
        request urlRequest: URLRequest,
        decoder: JSONDecoder = .nis,
        callbackQueue: DispatchQueue? = .main,
        completion: @escaping (NISResponse<Void>) -> Void
    ) -> NISCancellable {
        uncheckedRequest(
            request: urlRequest,
            of: NISEmptyResult.self,
            decoder: decoder,
            callbackQueue: callbackQueue,
            completion: { completion(.init(result: $0.result.map { _ in }, data: $0.data)) }
        )
    }
}

public extension NISRequestDispatcher {
    
    /// Modern concurrency-safe bridge for completion-based APIs.
    ///
    /// Unlike `uncheckedRequest`, this method requires `T: Sendable`,
    /// which allows values to safely cross concurrency domains without
    /// relying on unchecked containers.
    ///
    /// ## Key difference vs uncheckedRequest
    /// - does NOT use `NISUncheckedSendableBox`
    /// - enforces Sendable correctness at compile-time
    ///
    /// ## When to use
    /// - when your response models conform to `Sendable`
    /// - when you want stricter concurrency guarantees
    ///
    /// ## When NOT to use
    /// - when working with legacy non-Sendable models → use `uncheckedRequest`
    ///
    /// ## Cancellation
    /// Cancels the underlying async task.
    @discardableResult
    func request<T: Decodable & Sendable>(
        request urlRequest: URLRequest,
        of type: T.Type = T.self,
        decoder: JSONDecoder = .nis,
        callbackQueue: DispatchQueue? = .main,
        completion: @escaping @Sendable (NISResponse<T>) -> Void
    ) -> NISCancellable {
        let task = Task { [self] in
            let response = await request(urlRequest, as: type, decoder: decoder)
            guard !Task.isCancelled else { return }
            
            if let callbackQueue {
                callbackQueue.async { completion(response) }
            } else {
                completion(response)
            }
        }
        
        return NISRequestHandler(task: task)
    }
    
    /// Void-specialized variant of `request(_:of:...)`
    ///
    /// Maps decoded result to `Void` for endpoints where response body
    /// is not relevant.
    @discardableResult
    func request(
        request urlRequest: URLRequest,
        decoder: JSONDecoder = .nis,
        callbackQueue: DispatchQueue? = .main,
        completion: @escaping @Sendable (NISResponse<Void>) -> Void
    ) -> NISCancellable {
        request(
            request: urlRequest,
            of: NISEmptyResult.self,
            decoder: decoder,
            callbackQueue: callbackQueue,
            completion: { completion($0.mapValue { _ in }) }
        )
    }
}

import Combine

public extension NISRequestDispatcher {
    
    /// Creates a Combine publisher for executing a request and decoding its response.
    ///
    /// This is a Combine bridge over the async `request` API and serves as a
    /// thin wrapper without introducing additional behavior.
    ///
    /// ## Behavior
    /// - Executes the request when a subscriber requests demand
    /// - Emits exactly one `NISResponse<T>`
    /// - Completes immediately after emission
    /// - Ignores demand (single-shot publisher)
    ///
    /// ## Cancellation
    /// - Cancelling the subscription cancels the underlying async task
    /// - No values are delivered after cancellation
    ///
    /// ## Threading
    /// - The publisher does not enforce any specific delivery queue
    /// - Use `.receive(on:)` on the consumer side to control execution context
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.publisher(request, as: User.self)
    ///     .receive(on: DispatchQueue.main)
    ///     .sink { response in
    ///         // handle response
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The URL request to execute
    ///   - type: The expected decoded response type
    ///   - decoder: The decoder used to decode response data
    /// - Returns: A publisher emitting a single `NISResponse<T>`
    func publisher<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type = T.self,
        decoder: JSONDecoder = .nis
    ) -> AnyPublisher<NISResponse<T>, Never> {
        NISPublisher(
            dispatcher: self,
            request: request,
            decoder: decoder
        )
        .eraseToAnyPublisher()
    }
    
    /// Creates a Combine publisher for executing a request where no response body is expected.
    ///
    /// This is a convenience overload that maps any successful decoded value
    /// to `Void`, allowing callers to ignore response payloads.
    ///
    /// ## Behavior
    /// - Same as `publisher(_:as:decoder:)`
    /// - Maps `.success(_)` → `.success(())`
    /// - Leaves failures unchanged
    ///
    /// ## Use Cases
    /// - Endpoints that return no meaningful body
    /// - Fire-and-forget requests (e.g. POST/DELETE)
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.publisher(request)
    ///     .sink { response in
    ///         // response.result is Void on success
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The URL request to execute
    ///   - decoder: The decoder used to decode response data
    /// - Returns: A publisher emitting a single `NISResponse<Void>`
    func publisher(
        _ request: URLRequest,
        decoder: JSONDecoder = .nis
    ) -> AnyPublisher<NISResponse<Void>, Never> {
        publisher(
            request,
            as: NISEmptyResult.self,
            decoder: decoder
        )
        .map { $0.mapValue { _ in } }
        .eraseToAnyPublisher()
    }
}
