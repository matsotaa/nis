//
//  NISRecentResponseReusePolicy.swift
//  NIS
//
//  Created by Andrew Matsota on 14.04.2026.
//

import Foundation

/// Describes how the dispatcher may reuse a recently completed request result.
///
/// `NISRecentResponseReusePolicy` controls **short-lived reuse of completed requests**
/// and is distinct from in-flight deduplication.
///
/// ## Concepts
/// - **In-flight deduplication**
///   Shares work while a request is still executing.
/// - **Recent response reuse**
///   Reuses a completed response for a short period of time (TTL).
///
/// ## Behavior
/// - When `.disabled`:
///   - No completed responses are reused.
///   - Every request starts a new network operation (after in-flight phase).
///
/// - When enabled:
///   - Completed responses may be reused within the defined TTL window.
///   - Reuse applies only if allowed by the policy (success / failure).
///
/// ## Design goals
/// - reduce redundant requests caused by UI lifecycle (e.g. SwiftUI `.task`)
/// - improve perceived responsiveness
/// - avoid introducing full caching complexity
///
/// ## Safety considerations
/// This feature introduces **controlled staleness**.
/// It should only be enabled for endpoints where short delays are acceptable.
///
/// Avoid enabling for:
/// - financial or transactional data
/// - authentication/session state
/// - real-time or critical systems
/// 
public enum NISRecentResponseReusePolicy: Sendable {

    /// Disables reuse of completed responses.
    ///
    /// Every request will trigger a new network call once no in-flight task exists.
    case disabled

    /// Reuses **successful responses only** for a limited time window.
    ///
    /// - Parameter ttl:
    ///   Maximum time to live (in seconds) during which a successful response may be reused.
    ///
    /// - Note:
    ///   Failed responses are not reused in this mode.
    case successOnly(ttl: TimeInterval)

    /// Reuses both successful and failed responses.
    ///
    /// - Parameter ttl:
    ///   Maximum time to live (in seconds) during which a response may be reused.
    ///
    /// - Important:
    ///   Reusing failures may reduce retry storms but can delay recovery from transient issues.
    case successAndFailure(ttl: TimeInterval)
}

// MARK: - Helpers

public extension NISRecentResponseReusePolicy {

    /// Returns configured TTL(time to live) value, if reuse is enabled.
    var ttl: TimeInterval? {
        switch self {
        case .disabled:
            return nil
        case .successOnly(let ttl), .successAndFailure(let ttl):
            return max(0, ttl)
        }
    }

    /// Indicates whether successful responses may be reused.
    var allowsSuccess: Bool {
        switch self {
        case .disabled:
            return false
        case .successOnly, .successAndFailure:
            return true
        }
    }

    /// Indicates whether failed responses may be reused.
    var allowsFailure: Bool {
        switch self {
        case .successAndFailure:
            return true
        default:
            return false
        }
    }

    /// Indicates whether reuse is enabled.
    var isEnabled: Bool {
        (ttl ?? 0) > 0
    }
}
