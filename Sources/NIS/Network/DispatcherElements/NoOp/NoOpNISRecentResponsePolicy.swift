//
//  NoOpNISRecentResponsePolicy.swift
//  NIS
//
//  Created by Andrew Matsota on 14.04.2026.
//

import Foundation

/// A no-op implementation of `NISRecentResponseReusable`.
///
/// `NoOpNISRecentResponsePolicy` disables response reuse entirely,
/// ensuring that every request is executed independently.
///
/// ## Behavior
/// - Always returns `.disabled`
/// - No response reuse or caching is performed
///
/// ## Use Cases
/// - Default configuration when reuse is not desired
/// - Explicitly disabling reuse in performance-sensitive scenarios
///
/// ## Performance
/// No additional storage or lookup overhead is introduced.
///
/// ## Example
/// ```swift
/// dispatcher.responseReusePolicy = .noOp
/// ```
///
/// ## Notes
/// Guarantees that all requests hit the transport layer,
/// preserving standard networking semantics.
public enum NoOpNISRecentResponsePolicy: NISRecentResponseReusable {
    case shared
    
    public func policy(for request: URLRequest) -> NISRecentResponseReusePolicy {
        .disabled
    }
}

public extension NISRecentResponseReusable where Self == NoOpNISRecentResponsePolicy {
    
    /// Provides a no-op reuse policy that disables response reuse.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.responseReusePolicy = .noOp
    /// ```
    static var noOp: NoOpNISRecentResponsePolicy { .shared }
}
