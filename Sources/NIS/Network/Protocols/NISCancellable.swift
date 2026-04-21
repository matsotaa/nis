//
//  NISCancellable.swift
//  NIS
//
//  Created by Andrew Matsota on 20.04.2026.
//

/// Represents a cancellable unit of work.
///
/// `NISCancellable` defines a minimal interface for cancelling
/// an in-flight operation initiated by the SDK.
///
/// ## Purpose
/// This protocol is primarily used in completion-based APIs to provide
/// control over request lifecycle without exposing underlying execution details.
///
/// ## Behavior
/// - Calling `cancel()` requests termination of the associated operation
/// - Cancellation is cooperative and may not take effect immediately
///
/// ## Notes
/// - Constrained to reference types (`AnyObject`) to ensure identity semantics
/// - Implementations are expected to be lightweight wrappers over underlying mechanisms
///   such as `Task` or `URLSessionTask`
public protocol NISCancellable: AnyObject {
    
    /// Cancels the associated operation.
    func cancel()
}
