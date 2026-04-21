//
//  NoOpNISResponseDataAnalyzer.swift
//  NIS
//
//  Created by Andrew Matsota on 16.04.2026.
//

/// A no-op implementation of `NISResponseDataAnalyzable`.
///
/// `NoOpNISResponseDataAnalyzer` performs no analysis on response data
/// and acts as a safe default when no side-effect processing is required.
///
/// ## Behavior
/// - Does nothing when a response is received
/// - Does not mutate state or produce side effects
///
/// ## Use Cases
/// - Default configuration when analytics or logging is not needed
/// - Disabling response analysis without altering pipeline structure
///
/// ## Performance
/// Zero-cost implementation with no allocations or processing.
///
/// ## Example
/// ```swift
/// dispatcher.responseAnalyzer = .noOp
/// ```
///
/// ## Notes
/// Ensures the response analysis stage remains part of the pipeline
/// without introducing conditional branching.
public enum NoOpNISResponseDataAnalyzer: NISResponseDataAnalyzable {
    
    case shared
    
    public func analyze(responseData: NISResponseData) {
        // Intentionally left empty
    }
}

public extension NISResponseDataAnalyzable where Self == NoOpNISResponseDataAnalyzer {

    /// Provides a no-op response analyzer that performs no side effects.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.responseAnalyzer = .noOp
    /// ```
    static var noOp: NoOpNISResponseDataAnalyzer { .shared }
}
