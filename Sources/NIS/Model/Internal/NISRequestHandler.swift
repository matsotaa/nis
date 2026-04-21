//
//  NISRequestHandler.swift
//  NIS
//
//  Created by Andrew Matsota on 20.04.2026.
//

/// Internal implementation of `NISCancellable` backed by Swift Concurrency.
///
/// `NISRequestHandler` wraps a `Task` and exposes it through the
/// `NISCancellable` abstraction used by completion-based APIs.
///
/// ## Responsibilities
/// - bridges Swift Concurrency (`Task`) into a cancellable handle
/// - hides underlying execution details from public API
///
/// ## Behavior
/// - forwards `cancel()` to the underlying `Task`
/// - does not expose task state or result
///
/// ## Design
/// This type is intentionally kept internal to allow future changes
/// to the execution mechanism without affecting public API.
///
/// ## Notes
/// - lightweight and allocation-free wrapper
/// - relies on cooperative cancellation of Swift `Task`
internal final class NISRequestHandler: NISCancellable {
    
    private let task: Task<Void, Never>
    
    init(task: Task<Void, Never>) {
        self.task = task
    }
    
    func cancel() {
        task.cancel()
    }
}
