//
//  NoOpNISRequestRetrier.swift
//  NIS
//
//  Created by Andrew Matsota on 20.04.2026.
//

import Foundation

/// A no-op implementation of `NISRequestRetryable`.
///
/// `NoOpNISRequestRetrier` represents a retry strategy that never retries failed requests.
/// It is used as the default fallback when no retry behavior is explicitly configured.
///
/// ## Behavior
/// - Always returns `.doNotRetry`
/// - Does not inspect the request, error, or response
/// - Introduces no delay or side effects
///
/// ## Performance
/// This implementation is lightweight and incurs negligible overhead,
/// making it safe to use as a default strategy in all environments.
///
/// ## Usage
/// Used internally as the default retry strategy to ensure a consistent
/// execution pipeline without requiring optional handling.
///
/// ## Example
/// ```swift
/// dispatcher.retryStrategy = .noOp
/// ```
///
/// ## Notes
/// This type is implemented as a singleton enum (`.shared`) to avoid allocations
/// and ensure a single shared instance across the system.
public enum NoOpNISRequestRetrier: NISRequestRetryable {
    case shared
    
    public func shouldRetry(
        request: URLRequest,
        error: NISError,
        responseData: NISResponseData,
        retryCount: Int
    ) async -> NISRetryDecision {
        .doNotRetry
    }
}

public extension NISRequestRetryable where Self == NoOpNISRequestRetrier {

    /// A retry strategy that never retries.
    ///
    /// Returns `.doNotRetry` for all requests.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.retryStrategy = .noOp
    /// ```
    static var noOp: NoOpNISRequestRetrier { .shared }
}
