//
//  NISRequestAdaptable.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A component responsible for transforming a `URLRequest` before execution.
///
/// `NISRequestAdaptable` is part of the request preparation stage in the dispatcher
/// pipeline. It enables injecting cross-cutting concerns without coupling them
/// to request construction logic.
///
/// - Responsibilities:
///   - authentication (e.g. adding tokens)
///   - header enrichment (e.g. locale, device metadata)
///   - request signing (e.g. HMAC, custom headers)
///   - dynamic request mutation based on runtime state
///
/// - Execution:
///   Adapters are executed **before the request is sent**, typically as a pipeline.
///   Each adapter receives the request returned by the previous adapter.
///
/// - Concurrency:
///   This API is `async` to support:
///   - token refresh flows
///   - secure storage access
///   - remote configuration
///
/// - Error handling:
///   Throwing from this method **cancels request execution entirely**.
///
/// - Important:
///   Implementations should treat the incoming request as immutable and return
///   a modified copy. Avoid mutating shared instances.
///
/// - Composition:
///   Multiple adapters can be combined using `NISRequestAdapterComposer`.
public protocol NISRequestAdaptable {
//    requestModifier
    /// Transforms the provided request before execution.
    ///
    /// - Parameter request: Original request produced by the caller.
    /// - Returns: A modified request ready for dispatch.
    /// - Throws: An error if adaptation fails and the request should not proceed.
    func adapt(request: URLRequest) async throws -> URLRequest
}

public extension NISRequestAdaptable {

    /// Converts the current adapter into a composable pipeline.
    ///
    /// This method is the entry point for building adapter chains using
    /// `NISRequestAdapterComposer`.
    ///
    /// - Behavior:
    ///   - If the receiver is already a composer, it is returned as-is.
    ///   - Otherwise, a new composer is created containing this adapter.
    ///
    /// - Use case:
    ///   Enables fluent composition starting from a single adapter.
    ///
    /// - Example:
    /// ```swift
    /// dispatcher.requestAdapter = AuthAdapter()
    ///     .asComposer()
    ///     .appending(LocaleAdapter())
    ///     .appending(SigningAdapter())
    /// ```
    ///
    /// - Returns: A composer containing the current adapter.
    func asComposer() -> NISRequestAdapterComposer {
        if let composer = self as? NISRequestAdapterComposer {
            return composer
        }
        return NISRequestAdapterComposer([self])
    }
}
