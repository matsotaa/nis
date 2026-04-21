//
//  NISResponseAnalyzerComposer.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

import Foundation

/// A broadcast group of response analyzers.
///
/// `NISResponseAnalyzerComposer` executes all analyzers for the same
/// `NISResponseData` instance, making it suitable for fan-out use cases such as:
/// - analytics
/// - logging
/// - metrics collection
/// - custom diagnostics
///
/// - Execution:
///   All analyzers are invoked sequentially in the order they appear in `stack`.
///
/// - Behavior:
///   - every analyzer receives the same input
///   - there is no short-circuiting
///
/// - Example:
/// ```swift
/// let analyzer = NISResponseAnalyzerComposer(
///     LoggingAnalyzer(),
///     MetricsAnalyzer()
/// )
///
/// dispatcher.responseAnalyzer = analyzer
/// ```
public struct NISResponseAnalyzerComposer: NISResponseDataAnalyzable, NISComposable {
    
    /// Ordered analyzer stack executed for each response.
    public let stack: [NISResponseDataAnalyzable]

    /// Creates an analyzer group.
    ///
    /// - Parameter stack: Analyzers to execute in order.
    public init(_ stack: [NISResponseDataAnalyzable]) {
        self.stack = stack
    }

    /// Broadcasts the response data to all analyzers in the stack.
    ///
    /// - Parameter responseData: Raw response data to analyze.
    public func analyze(responseData: NISResponseData) {
        for analyzer in stack {
            analyzer.analyze(responseData: responseData)
        }
    }
}
