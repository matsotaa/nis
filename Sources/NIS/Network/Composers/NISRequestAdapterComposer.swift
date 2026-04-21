//
//  NISRequestAdapterComposer.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

import Foundation

/// A sequential pipeline of request adapters.
///
/// `NISRequestAdapterComposer` combines multiple `AnyNISRequestAdapter`
/// instances into a single adapter while preserving execution order.
///
/// Each adapter receives the request produced by the previous adapter.
///
/// - Execution:
///   Adapters are executed sequentially in the order they appear in `stack`.
///
/// - Failure behavior:
///   If any adapter throws, composition stops immediately and the error is
///   propagated back to the caller.
///
/// - Concurrency:
///   Adapters are awaited one by one. No parallel adaptation is performed.
///
/// - Example:
/// ```swift
/// let adapter = NISRequestAdapterComposer(
///     AuthAdapter(),
///     LocaleAdapter(),
///     SigningAdapter()
/// )
///
/// dispatcher.requestAdapter = adapter
/// ```
///
/// - Fluent example:
/// ```swift
/// dispatcher.requestAdapter = AuthAdapter()
///     .appending(LocaleAdapter())
///     .appending(SigningAdapter())
/// ```
public struct NISRequestAdapterComposer: NISRequestAdaptable, NISComposable {
    
    /// Ordered adapter stack executed during request preparation.
    public let stack: [NISRequestAdaptable]

    /// Creates an adapter pipeline.
    ///
    /// - Parameter stack: Adapters to execute in order.
    public init(_ stack: [NISRequestAdaptable]) {
        self.stack = stack
    }

    /// Applies all adapters sequentially to the provided request.
    ///
    /// - Parameter request: Original request.
    /// - Returns: Fully adapted request.
    /// - Throws: The first error thrown by any adapter in the stack.
    public func adapt(request: URLRequest) async throws -> URLRequest {
        var current = request

        for adapter in stack {
            current = try await adapter.adapt(request: current)
        }

        return current
    }
}
