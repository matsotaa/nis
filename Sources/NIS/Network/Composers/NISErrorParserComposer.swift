//
//  NISErrorParserComposer.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

import Foundation

/// A fallback chain of backend error parsers.
///
/// `NISErrorParserComposer` evaluates multiple parsers in order and returns
/// the first successfully parsed error.
///
/// This is useful when supporting:
/// - multiple backend services
/// - different error payload schemas
/// - versioned response formats
///
/// - Execution:
///   Parsers are evaluated sequentially in the order they appear in `stack`.
///
/// - Behavior:
///   - first non-`nil` parsed error wins
///   - remaining parsers are not evaluated
///
/// - Example:
/// ```swift
/// let parser = NISErrorParserComposer(
///     GraphQLErrorParser(),
///     RESTErrorParser()
/// )
///
/// dispatcher.errorParser = parser
/// ```
public struct NISErrorParserComposer: NISErrorParsable, NISComposable {
    
    /// Ordered parser stack evaluated during backend error parsing.
    public let stack: [NISErrorParsable]

    /// Creates an error parser chain.
    ///
    /// - Parameter stack: Parsers to evaluate in order.
    public init(_ stack: [NISErrorParsable]) {
        self.stack = stack
    }

    /// Attempts to parse an error from response payload using the configured parsers.
    ///
    /// - Parameters:
    ///   - data: Optional response body.
    ///   - response: Optional HTTP response.
    /// - Returns: First parsed error, or `nil` if all parsers fail.
    public func parse(data: Data?, response: HTTPURLResponse?) -> Error? {
        for parser in stack {
            if let error = parser.parse(data: data, response: response) {
                return error
            }
        }
        
        return nil
    }
}
