//
//  NISRequestRetrierComposer.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

import Foundation

/// A sequential chain of request retriers.
///
/// `NISRequestRetrierComposer` evaluates multiple retry strategies in order
/// and returns the first decision that requests a retry.
///
/// This is useful when combining different retry concerns, such as:
/// - transport retry rules
/// - authentication refresh retry
/// - backend-specific retry conditions
///
/// - Execution:
///   Retriers are evaluated sequentially in the order they appear in `stack`.
///
/// - Behavior:
///   - first decision with `shouldRetry == true` wins
///   - remaining retriers are not evaluated
///   - if no retrier requests retry, the chain returns `shouldRetry == false`
///
/// - Example:
/// ```swift
/// let retrier = NISRequestRetrierComposer(
///     NetworkReachabilityRetrier(),
///     UnauthorizedTokenRefreshRetrier()
/// )
///
/// dispatcher.retryStrategy = retryStrategy
/// ```
public struct NISRequestRetrierComposer: NISRequestRetryable, NISComposable {
    
    /// Ordered retrier stack evaluated during retry decision making.
    public let stack: [NISRequestRetryable]

    /// Creates a retrier chain.
    ///
    /// - Parameter stack: Retriers to evaluate in order.
    public init(_ stack: [NISRequestRetryable]) {
        self.stack = stack
    }

    /// Evaluates whether request execution should be retried.
    ///
    /// - Parameters:
    ///   - request: Original request.
    ///   - error: Normalized request error.
    ///   - responseData: Raw response data associated with failure.
    ///   - retryCount: Current retry attempt count.
    /// - Returns: First positive retry decision, or a decision with `shouldRetry == false`.
    public func shouldRetry(
        request: URLRequest,
        error: NISError,
        responseData: NISResponseData,
        retryCount: Int
    ) async -> NISRetryDecision {
        for retrier in stack {
            let decision = await retrier.shouldRetry(
                request: request,
                error: error,
                responseData: responseData,
                retryCount: retryCount
            )

            if decision.shouldRetry {
                return decision
            }
        }

        return .init(shouldRetry: false)
    }
}
