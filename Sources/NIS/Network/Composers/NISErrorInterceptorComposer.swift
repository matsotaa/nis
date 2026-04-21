//
//  NISErrorInterceptorComposer.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

import Foundation

/// A sequential pipeline of dispatcher error interceptors.
///
/// `NISErrorInterceptorComposer` allows multiple interceptors to process the same
/// dispatcher failure flow while preserving strict execution order.
///
/// Each interceptor receives the error returned by the previous interceptor,
/// making the pipeline suitable for:
/// - normalization
/// - enrichment
/// - remapping
/// - logging-aware transformation
///
/// - Execution:
///   Interceptors are executed sequentially in the order they appear in `stack`.
///
/// - Important:
///   The output of one interceptor becomes the input of the next interceptor.
///   Order directly affects the final resulting error.
///
/// - Example:
/// ```swift
/// let interceptor = NISErrorInterceptorComposer(
///     CancellationInterceptor(),
///     BackendErrorNormalizationInterceptor()
/// )
///
/// dispatcher.errorInterceptor = interceptor
/// ```
public struct NISErrorInterceptorComposer: NISDispatcherErrorInterceptable, NISComposable {
    
    /// Ordered interceptor stack executed during dispatcher error processing.
    public let stack: [NISDispatcherErrorInterceptable]

    /// Creates an interceptor pipeline.
    ///
    /// - Parameter stack: Interceptors to execute in order.
    public init(_ stack: [NISDispatcherErrorInterceptable]) {
        self.stack = stack
    }

    /// Processes the provided error through the full interceptor pipeline.
    ///
    /// - Parameters:
    ///   - error: Initial dispatcher error.
    ///   - request: Request associated with failure.
    ///   - response: Optional HTTP response.
    ///   - data: Optional response body.
    /// - Returns: Final transformed error after all interceptors have run.
    public func interceptError(
        error: NISError,
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?
    ) async -> NISError {
        var current = error

        for interceptor in stack {
            current = await interceptor.interceptError(
                error: current,
                request: request,
                response: response,
                data: data
            )
        }

        return current
    }
}
