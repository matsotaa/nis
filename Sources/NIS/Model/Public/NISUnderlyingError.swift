//
//  NISUnderlyingError.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
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

public extension NISUnderlyingError {
    
    /// Returns whether the wrapped error matches a specific NSError
    /// domain and error code.
    ///
    /// This uses Swift `Error` bridging to `NSError` and compares
    /// semantic error identity via `(domain, code)`.
    ///
    /// Useful for inspecting specific transport or Foundation errors
    /// without exposing or depending on concrete underlying error types.
    ///
    /// - Parameters:
    ///   - domain: NSError domain to match.
    ///   - code: NSError code to match.
    ///
    /// - Returns: `true` if the bridged underlying error matches the
    ///   provided domain and code.
    func matches(
        domain: String,
        code: Int
    ) -> Bool {
        let nsError = rawValue as NSError
        return nsError.domain == domain && nsError.code == code
    }
    
    /// Returns whether the wrapped error matches another error by comparing
    /// their bridged NSError domain and code.
    ///
    /// This is a convenience overload over `matches(domain:code:)`.
    ///
    /// - Parameter error: Error to compare against.
    ///
    /// - Returns: `true` if both errors resolve to the same NSError
    ///   domain and code.
    func matches(error: Error) -> Bool {
        let error = error as NSError
        return matches(domain: error.domain, code: error.code)
    }
}
