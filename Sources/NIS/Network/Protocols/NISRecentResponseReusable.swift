//
//  NISRecentResponseReusable.swift
//  NIS
//
//  Created by Andrew Matsota on 14.04.2026.
//

import Foundation

/// Defines a rule that determines whether a request is eligible for recent response reuse.
///
/// `NISRecentResponseReusable` is part of the dispatcher’s **response reuse subsystem**,
/// enabling fine-grained, per-request control over short-lived response reuse.
///
/// ## Overview
/// Implementations inspect a fully prepared `URLRequest` and return a
/// `NISRecentResponseReusePolicy` describing whether reuse is allowed.
///
/// This enables:
/// - selective reuse for specific endpoints (e.g. `/feed`, `/profile`)
/// - dynamic behavior via remote configuration (feature flags, JSON)
/// - environment-specific tuning (debug vs production)
///
/// ## Execution Context
/// The rule is evaluated **after request adaptation**, meaning:
/// - headers are finalized (auth, locale, etc.)
/// - URL and query parameters are final
/// - HTTP body is fully constructed
///
/// ## Resolution Model
/// The final reuse policy is resolved using:
///
/// 1. Composed rules (`NISRecentResponseReusable`, evaluated in order)
/// 2. Dispatcher default (`NISRequestDispatcher.responseReusePolicy`)
///
/// When used in a composition (e.g. `NISRecentResponseComposer`):
/// - rules are evaluated sequentially
/// - evaluation stops at the **first non-`.disabled` policy**
///
/// ## Matching Contract (Critical)
/// Implementations **must strictly follow**:
///
/// - Return `.disabled` if the rule does not apply
/// - Do not return an enabled policy for unrelated requests
///
/// Violating this contract may:
/// - short-circuit more specific rules
/// - override intended fallback behavior
/// - produce incorrect reuse decisions
///
/// ## Ordering Guidelines
/// When composing multiple rules:
/// - place **specific rules first**
/// - place **broad/default rules last**
///
/// ## Performance Requirements
/// This method is executed **for every request**.
///
/// Implementations must be:
/// - deterministic
/// - fast (constant or near-constant time)
/// - side-effect free
///
/// ## Thread Safety
/// Must be safe for concurrent execution.
///
/// ## Example
/// ```swift
/// struct FeedReuseDecider: NISRecentResponseReusable {
///     func policy(for request: URLRequest) -> NISRecentResponseReusePolicy {
///         if request.url?.path.contains("/feed") == true {
///             return .successOnly(ttl: 2)
///         }
///         return .disabled
///     }
/// }
/// ```
public protocol NISRecentResponseReusable {

    /// Determines the reuse policy for a given request.
    ///
    /// - Parameter request:
    ///   Fully adapted request, ready for execution.
    ///
    /// - Returns:
    ///   A reuse policy describing whether and how the response may be reused.
    ///
    /// ## Contract
    /// - MUST return `.disabled` if the rule does not match
    /// - MUST NOT return an enabled policy unconditionally
    /// - MUST be deterministic for identical inputs
    ///
    /// ## Performance Notes
    /// - Avoid expensive operations (regex, heavy parsing)
    /// - Prefer simple checks (path, method, headers)
    func policy(for request: URLRequest) -> NISRecentResponseReusePolicy
}

public extension NISRecentResponseReusable {

    /// Wraps the current rule into a composable pipeline.
    ///
    /// ## Behavior
    /// - Returns self if already a composer
    /// - Otherwise wraps into `NISRecentResponseComposer`
    ///
    /// ## Usage
    /// ```swift
    /// dispatcher.responseReusePolicy = FeedReuseDecider()
    ///     .asComposer()
    ///     .appending(ProfileReuseDecider())
    /// ```
    ///
    /// - Returns: A composer containing this rule.
    func asComposer() -> NISRecentResponseComposer {
        if let composer = self as? NISRecentResponseComposer {
            return composer
        }
        return NISRecentResponseComposer([self])
    }
}
