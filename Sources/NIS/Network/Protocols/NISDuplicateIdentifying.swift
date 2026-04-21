//
//  NISDuplicateIdentifying.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A component responsible for preventing duplicate request execution.
///
/// `NISDuplicateIdentifying` enables request deduplication by assigning
/// a unique identifier to requests.
///
/// - Responsibilities:
///   - detect identical in-flight requests
///   - ensure only one network task is executed
///   - fan-out the result to multiple callers
///
/// - Behavior:
///   - returning `nil` disables deduplication for the request
///   - identical hashes indicate requests that should share execution
///
/// - Important:
///   The hash must be stable and deterministic for equivalent requests.
///   Incorrect hashing may lead to unintended request merging.
///
/// - Note:
///   Typically based on URL, method, headers, and body.
public protocol NISDuplicateIdentifying {

    /// Returns a unique identifier for the given request.
    ///
    /// - Parameter request: Request to evaluate.
    /// - Returns: A hash identifying equivalent requests, or `nil` if deduplication should not apply.
    func uniqueHash(for request: URLRequest) -> Int?
}
