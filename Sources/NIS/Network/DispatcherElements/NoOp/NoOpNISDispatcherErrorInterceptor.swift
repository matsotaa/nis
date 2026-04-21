//
//  NoOpNISDispatcherErrorInterceptor.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A no-op implementation of `NISDispatcherErrorInterceptable`.
///
/// `NoOpNISDispatcherErrorInterceptor` forwards errors unchanged,
/// providing a default behavior when no error transformation is required.
///
/// ## Behavior
/// - Returns the original `NISError` without modification
/// - Does not inspect or alter request/response context
///
/// ## Use Cases
/// - Default configuration when no custom error handling is needed
/// - Disabling interception without changing pipeline structure
///
/// ## Performance
/// Minimal overhead; performs a direct pass-through.
///
/// ## Example
/// ```swift
/// dispatcher.errorInterceptor = .noOp
/// ```
///
/// ## Notes
/// Maintains a consistent error handling stage in the pipeline
/// without introducing side effects or branching logic.
public enum NoOpNISDispatcherErrorInterceptor: NISDispatcherErrorInterceptable {
    case shared
    
    public func interceptError(
        error: NISError,
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?
    ) async -> NISError {
        error
    }
}

public extension NISDispatcherErrorInterceptable where Self == NoOpNISDispatcherErrorInterceptor {
    
    /// Provides a no-op error interceptor that forwards errors unchanged.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.errorInterceptor = .noOp
    /// ```
    static var noOp: NoOpNISDispatcherErrorInterceptor { .shared }
}
