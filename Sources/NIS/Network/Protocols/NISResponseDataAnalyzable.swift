//
//  NISResponseDataAnalyzable.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A component responsible for analyzing successful response data.
///
/// `NISResponseDataAnalyzable` is used for side-effect operations that do not
/// affect request execution flow.
///
/// - Responsibilities:
///   - logging
///   - analytics
///   - metrics collection
///   - debugging instrumentation
///
/// - Execution:
///   Analyzers are typically executed after a successful response is received.
///
/// - Behavior:
///   - does not modify response
///   - does not affect control flow
///   - should be lightweight and non-blocking
///
/// - Important:
///   Heavy operations should be offloaded to background processing when possible.
public protocol NISResponseDataAnalyzable {

    /// Processes response data.
    ///
    /// - Parameter responseData: Raw response data.
    func analyze(responseData: NISResponseData)
}

public extension NISResponseDataAnalyzable {

    /// Converts the analyzer into a composable broadcast group.
    ///
    /// Enables executing multiple analyzers for the same response data.
    ///
    /// - Behavior:
    ///   - All analyzers are executed
    ///   - No short-circuiting
    ///   - Order is preserved
    ///
    /// - Example:
    /// ```swift
    /// dispatcher.responseAnalyzer = LoggingAnalyzer()
    ///     .asComposer()
    ///     .appending(MetricsAnalyzer())
    /// ```
    ///
    /// - Returns: A composer containing the current analyzer.
    func asComposer() -> NISResponseAnalyzerComposer {
        if let composer = self as? NISResponseAnalyzerComposer {
            return composer
        }
        return NISResponseAnalyzerComposer([self])
    }
}
