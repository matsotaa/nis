//
//  NISRequestRetryable.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A component responsible for determining whether a failed request should be retried.
///
/// `NISRequestRetryable` defines retry policies based on request context,
/// error type, and response data.
///
/// - Responsibilities:
///   - retry on network failures
///   - retry after authentication refresh
///   - retry based on backend-specific rules
///
/// - Execution:
///   Retriers are typically composed and evaluated sequentially.
///   The first retrier that requests retry stops evaluation.
///
/// - Important:
///   Retriers must be idempotent and should not mutate shared state unexpectedly.
///
/// - Note:
///   Retry decisions may include delay, backoff strategy, or immediate retry.
public protocol NISRequestRetryable {
    
    /// Determines whether a request should be retried.
    ///
    /// - Parameters:
    ///   - request: The original request.
    ///   - error: The normalized error.
    ///   - responseData: Raw response context.
    ///   - retryCount: Current retry attempt count.
    /// - Returns: A retry decision describing whether to retry and how.
    func shouldRetry(
        request: URLRequest,
        error: NISError,
        responseData: NISResponseData,
        retryCount: Int
    ) async -> NISRetryDecision
}

public extension NISRequestRetryable {

    /// Converts the retrier into a composable retry chain.
    ///
    /// This allows combining multiple retry strategies into a single decision pipeline.
    ///
    /// - Behavior:
    ///   - Retriers are evaluated in order
    ///   - First retrier returning `shouldRetry == true` wins
    ///   - Remaining retriers are skipped
    ///
    /// - Example:
    /// ```swift
    /// dispatcher.retryStrategy = NetworkRetrier()
    ///     .asComposer()
    ///     .appending(AuthRefreshRetrier())
    /// ```
    ///
    /// - Returns: A composer containing the current retrier.
    func asComposer() -> NISRequestRetrierComposer {
        if let composer = self as? NISRequestRetrierComposer {
            return composer
        }
        return NISRequestRetrierComposer([self])
    }
}
