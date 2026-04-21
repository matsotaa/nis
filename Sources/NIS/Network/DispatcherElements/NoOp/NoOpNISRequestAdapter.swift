//
//  NoOpNISRequestAdapter.swift
//  NIS
//
//  Created by Andrew Matsota on 20.04.2026.
//

import Foundation

/// A no-op implementation of `NISRequestAdaptable`.
///
/// `NoOpNISRequestAdapter` returns the original request unchanged,
/// providing a default behavior when no request modification is required.
///
/// ## Behavior
/// - Returns the input `URLRequest` as-is
/// - Does not modify headers, body, or URL
///
/// ## Use Cases
/// - Default adapter when no authentication or mutation is needed
/// - Placeholder to maintain a consistent request pipeline
///
/// ## Performance
/// Minimal overhead; performs a single pass-through operation.
///
/// ## Example
/// ```swift
/// dispatcher.requestAdapter = .noOp
/// ```
///
/// ## Notes
/// Keeps the adaptation stage active without introducing optional logic.
public enum NoOpNISRequestAdapter: NISRequestAdaptable {

    case shared
    
    public func adapt(request: URLRequest) async throws -> URLRequest {
        request
    }
}

public extension NISRequestAdaptable where Self == NoOpNISRequestAdapter {

    /// A request adapter that returns the request unchanged.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.requestAdapter = .noOp
    /// ```
    static var noOp: NoOpNISRequestAdapter { .shared }
}
