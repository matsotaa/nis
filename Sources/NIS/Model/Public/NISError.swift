//
//  NISError.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A type-erased wrapper for underlying errors used within `NISError`.
///
/// This wrapper preserves the original error while conforming to `Sendable`,
/// allowing it to safely cross concurrency boundaries.
///
/// - Important:
///   The wrapped `Error` is not guaranteed to be `Sendable`. This type uses
///   `@unchecked Sendable`, meaning thread-safety is the responsibility of
///   the caller.
///
/// - Use case:
///   - Preserving original system or third-party errors
///   - Passing errors through async/concurrent pipelines without losing context
///
/// - Note:
///   Consumers can access the original error via `rawValue`.
public struct NISUnderlyingError: Error, @unchecked Sendable {
    
    /// Original error captured by NIS.
    public let rawValue: Error

    /// Wraps any error into `NISUnderlyingError`.
    ///
    /// - Parameter rawValue: The original error to preserve.
    public init(_ rawValue: Error) {
        self.rawValue = rawValue
    }
}

/// Unified error type used across the NIS networking pipeline.
///
/// `NISError` provides a consistent abstraction over different failure sources:
/// - request lifecycle
/// - transport layer
/// - response validation
/// - decoding
///
/// Designed for:
/// - predictable error handling
/// - structured logging / analytics
/// - preserving underlying error context
///
/// - Important:
///   Associated underlying errors are wrapped in `NISUnderlyingError`
///   to retain original failure details.
///
/// - Note:
///   This enum is `Sendable` and safe to propagate across concurrency domains.
public enum NISError: Error, Sendable {

    /// Request was explicitly cancelled.
    ///
    /// Typically corresponds to:
    /// - `Task.cancel()`
    /// - `URLSessionTask.cancel()`
    case cancelled

    /// Response contained no data when data was expected.
    ///
    /// Indicates:
    /// - empty body
    /// - missing payload
    case emptyResponse

    /// Response could not be interpreted as a valid HTTP or expected format.
    ///
    /// Examples:
    /// - non-HTTP response
    /// - corrupted metadata
    case invalidResponse

    /// Failure during decoding of response payload.
    ///
    /// Wraps underlying decoding error (e.g. `DecodingError`).
    case decoding(NISUnderlyingError)

    /// Transport-level failure.
    ///
    /// Covers:
    /// - network connectivity issues
    /// - request timeouts
    /// - TLS / SSL errors
    /// - URLSession errors
    case transport(NISUnderlyingError)

    /// Server responded with non-success HTTP status code.
    ///
    /// - Parameters:
    ///   - statusCode: HTTP status code returned by server
    ///   - data: Optional raw response body (useful for debugging/logging)
    ///   - underlyingError: Optional lower-level error (if available)
    case invalidStatusCode(Int, Data?, NISUnderlyingError?)

    /// Fallback case for uncategorized errors.
    ///
    /// Used when error does not fit into predefined categories.
    case other(NISUnderlyingError)
}

// MARK: - Convenience Constructors

public extension NISError {

    /// Wraps an error as `.decoding`.
    ///
    /// - Parameter error: Original decoding error.
    /// - Returns: `NISError.decoding`
    static func decoding(_ error: Error) -> Self {
        .decoding(.init(error))
    }

    /// Wraps an error as `.transport`.
    ///
    /// - Parameter error: Original transport error.
    /// - Returns: `NISError.transport`
    static func transport(_ error: Error) -> Self {
        .transport(.init(error))
    }

    /// Wraps an error as `.other`.
    ///
    /// - Parameter error: Original error.
    /// - Returns: `NISError.other`
    static func other(_ error: Error) -> Self {
        .other(.init(error))
    }
}
