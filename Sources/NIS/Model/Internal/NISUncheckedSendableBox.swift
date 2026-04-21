//
//  NISUncheckedSendableBox.swift
//  NIS
//
//  Created by Andrew Matsota on 20.04.2026.
//

/// Internal helper that bridges values across concurrency boundaries
/// without requiring them to conform to `Sendable`.
///
/// `NISUncheckedSendableBox` is used only inside legacy compatibility APIs,
/// where the SDK needs to move callback-related values from async/await-based
/// execution into completion-based delivery.
///
/// ## Why this exists
/// Swift's strict concurrency model requires values captured by certain
/// asynchronous closures (such as `Task` bodies or queue hops) to be
/// `Sendable`.
///
/// Legacy completion-based APIs often work with values that are not formally
/// marked as `Sendable`, even when they are practically safe to forward in a
/// controlled way.
///
/// This box provides an explicit escape hatch for those cases.
///
/// ## Intended use
/// This type is meant only for:
/// - internal SDK bridging
/// - short-lived callback delivery
/// - controlled transport of immutable or effectively immutable values
///
/// Typical examples include:
/// - completion closures
/// - response containers
/// - callback delivery helpers used inside legacy APIs
///
/// ## Safety model
/// `@unchecked Sendable` disables compile-time verification.
/// This means the compiler trusts the SDK implementation to ensure the boxed
/// value is used safely.
///
/// The SDK must therefore guarantee that:
/// - the boxed value is not mutated concurrently
/// - the boxed value is forwarded in a narrow, well-defined flow
/// - the box is not used as a general-purpose shared state container
///
/// ## Important
/// This type is **not** a general concurrency primitive.
///
/// Do **not** use it for:
/// - long-lived shared state
/// - mutable objects accessed from multiple execution contexts
/// - bypassing `Sendable` rules in the SDK core
/// - cross-feature storage or synchronization
///
/// ## Design notes
/// - implemented as a `final class` to preserve reference semantics
/// - stores a single immutable value
/// - intended to remain private/internal to the SDK
///
/// ## When to use
/// Prefer modern `Sendable`-safe APIs whenever possible.
/// Use this box only where a legacy bridge is required and the SDK fully
/// controls the execution path.
internal final class NISUncheckedSendableBox<T>: @unchecked Sendable {

    /// Boxed value forwarded through an internal legacy bridge.
    let value: T

    /// Creates a box around the provided value.
    ///
    /// - Parameter value:
    ///   Value to bridge across an internal concurrency boundary.
    init(_ value: T) {
        self.value = value
    }
}
