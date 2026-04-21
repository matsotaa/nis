//
//  NoOpNISDuplicateStrategy.swift
//  NIS
//
//  Created by Andrew Matsota on 16.04.2026.
//

import Foundation

/// A no-op implementation of `NISDuplicateIdentifying`.
///
/// `NoOpNISDuplicateStrategy` disables duplicate request detection,
/// allowing all requests to execute independently.
///
/// ## Behavior
/// - Always returns `nil` for `uniqueHash`
/// - No in-flight request coalescing is performed
///
/// ## Use Cases
/// - Default configuration when deduplication is not required
/// - Scenarios where each request must be executed independently
///
/// ## Performance
/// No hashing or storage overhead is introduced.
///
/// ## Example
/// ```swift
/// dispatcher.duplicateStrategy = .noOp
/// ```
///
/// ## Notes
/// Ensures predictable request execution without shared results.
public enum NoOpNISDuplicateStrategy: NISDuplicateIdentifying {
    case shared
    
    public func uniqueHash(for request: URLRequest) -> Int? {
        nil
    }
}

public extension NISDuplicateIdentifying where Self == NoOpNISDuplicateStrategy {
    
    /// Provides a no-op duplicate prevention strategy.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.duplicateStrategy = .noOp
    /// ```
    static var noOp: NoOpNISDuplicateStrategy { .shared }
}
