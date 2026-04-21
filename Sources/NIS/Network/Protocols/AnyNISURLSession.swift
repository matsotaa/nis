//
//  AnyNISURLSession.swift
//  NIS
//
//  Created by Andrew Matsota on 07.04.2026.
//

import Foundation

/// Async-first abstraction for any session capable of executing a `URLRequest`.
///
/// Conforming types can be injected into higher-level networking objects,
/// including SDK modules or app-specific layers.
///
/// Foundation's `URLSession` already provides a native async implementation, so it conforms automatically.
public protocol AnyNISURLSession {
    
    /// Executes the given request and returns raw data with the URL response.
    ///
    /// - Parameter request: Prepared `URLRequest`.
    /// - Returns: Response payload and metadata.
    /// - Throws: Transport error, cancellation error, or session-specific security error.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: AnyNISURLSession { }
