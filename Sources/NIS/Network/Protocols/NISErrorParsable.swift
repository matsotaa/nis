//
//  NISErrorParsable.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A component responsible for parsing backend-specific error payloads.
///
/// `NISErrorParsable` is used to extract structured errors from unsuccessful
/// HTTP responses.
///
/// - Responsibilities:
///   - decode backend error formats (JSON, GraphQL, REST, etc.)
///   - map raw payloads into meaningful `Error` values
///
/// - Execution:
///   Typically used in a fallback chain (`NISErrorParserComposer`),
///   where multiple parsers are evaluated in order.
///
/// - Behavior:
///   - return `nil` if parsing is not applicable
///   - return non-nil error if parsing succeeds
///
/// - Important:
///   This parser should not throw — it must fail gracefully and allow
///   other parsers to attempt decoding.
public protocol NISErrorParsable {

    /// Attempts to parse an error from response data.
    ///
    /// - Parameters:
    ///   - data: Raw response body.
    ///   - response: HTTP response metadata.
    /// - Returns: Parsed error, or `nil` if parsing fails.
    func parse(data: Data?, response: HTTPURLResponse?) -> Error?
}

public extension NISErrorParsable {

    /// Converts the parser into a composable fallback chain.
    ///
    /// Enables combining multiple parsers where each one attempts to interpret
    /// backend error payloads.
    ///
    /// - Behavior:
    ///   - First parser returning non-nil error wins
    ///   - Remaining parsers are not evaluated
    ///
    /// - Example:
    /// ```swift
    /// dispatcher.errorParser = RESTParser()
    ///     .asComposer()
    ///     .appending(GraphQLParser())
    /// ```
    ///
    /// - Returns: A composer containing the current parser.
    func asComposer() -> NISErrorParserComposer {
        if let composer = self as? NISErrorParserComposer {
            return composer
        }
        return NISErrorParserComposer([self])
    }
}
