//
//  NISRecentResponseComposer.swift
//  NIS
//
//  Created by Andrew Matsota on 16.04.2026.
//

import Foundation

public struct NISRecentResponseComposer: NISRecentResponseReusable, NISComposable {

    /// Ordered adapter stack executed during request preparation.
    public let stack: [NISRecentResponseReusable]

    /// Creates an adapter pipeline.
    ///
    /// - Parameter stack: Adapters to execute in order.
    public init(_ stack: [NISRecentResponseReusable]) {
        self.stack = stack
    }
    
    /// Resolves reuse policy by evaluating stack in order.
    ///
    /// ## Behavior
    /// - Iterates through all providers
    /// - Returns first non-disabled policy
    /// - Falls back to `.disabled` if none matched
    ///
    /// ## Rationale
    /// Ensures predictable and composable behavior:
    /// - higher-priority rules should be placed earlier
    /// - avoids conflicting policy merging
    public func policy(for request: URLRequest) -> NISRecentResponseReusePolicy {
        for provider in stack {
            let policy = provider.policy(for: request)
            
            if policy.isEnabled {
                return policy
            }
        }
        
        return .disabled
    }
}
