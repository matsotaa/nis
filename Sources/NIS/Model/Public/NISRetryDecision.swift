//
//  NISRetryDecision.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// Represents a decision produced by a retry strategy.
///
/// `NISRetryDecision` defines whether a failed request should be retried
/// and optionally specifies a delay before the next attempt.
///
/// ## Behavior
/// - `shouldRetry == true` indicates that the dispatcher should perform another attempt
/// - `delay` defines how long to wait before retrying, in seconds
///
/// ## Delay semantics
/// - A value of `0` means immediate retry
/// - A positive value introduces a delay before the next attempt
/// - Negative values are not expected and should be avoided by implementations
///
/// ## Usage
/// Instances of `NISRetryDecision` are returned from `NISRequestRetryable`
/// implementations and consumed by the dispatcher to control retry flow.
///
/// ## Example
/// ```swift
/// // Retry immediately
/// .init(shouldRetry: true)
///
/// // Retry after 2 seconds
/// .init(shouldRetry: true, delay: 2)
///
/// // Do not retry
/// .doNotRetry
/// ```
///
/// ## Notes
/// This type is intentionally lightweight and immutable to ensure predictable
/// behavior across asynchronous retry pipelines.
public struct NISRetryDecision {
    
    /// Indicates whether the request should be retried.
    public let shouldRetry: Bool
    
    /// Delay before the next retry attempt, in seconds.
    public let delay: TimeInterval
    
    /// Creates a retry decision.
    ///
    /// - Parameters:
    ///   - shouldRetry: Whether another attempt should be performed.
    ///   - delay: Delay before retrying, in seconds. Defaults to `0`.
    public init(shouldRetry: Bool, delay: TimeInterval = 0) {
        self.shouldRetry = shouldRetry
        self.delay = delay
    }
}

public extension NISRetryDecision {
    
    /// A predefined decision indicating that the request should not be retried.
    ///
    /// ## Behavior
    /// - `shouldRetry == false`
    /// - `delay == 0`
    ///
    /// ## Usage
    /// Commonly returned from retry strategies to signal that a failure
    /// should be propagated without additional attempts.
    ///
    /// ## Example
    /// ```swift
    /// return .doNotRetry
    /// ```
    static var doNotRetry: NISRetryDecision { .init(shouldRetry: false) }
}
