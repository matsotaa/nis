//
//  DefaultNISDuplicateStrategy.swift
//  NIS
//
//  Created by Andrew Matsota on 14.04.2026.
//

import Foundation

public extension NISDuplicateIdentifying where Self == DefaultNISDuplicateStrategy {
    
    /// Creates a default duplicate detection strategy.
    ///
    /// This factory provides a convenient way to configure how request identity
    /// is calculated for in-flight deduplication.
    ///
    /// - Parameters:
    ///   - includeHeaders: Whether HTTP headers should be included in the identity hash. Default is `false`.
    ///   - headerWhitelist: Optional set of headers to include when `includeHeaders == true`.
    ///     If `nil`, all headers are included.
    ///
    /// - Returns: A configured `DefaultNISDuplicateStrategy`.
    ///
    /// ## Example
    /// ```swift
    /// dispatcher.duplicateStrategy = .nis()
    ///
    /// dispatcher.duplicateStrategy = .nis(includeHeaders: true)
    ///
    /// dispatcher.duplicateStrategy = .nis(
    ///     includeHeaders: true,
    ///     headerWhitelist: ["Authorization"]
    /// )
    /// ```
    ///
    /// ## Notes
    /// Including headers increases hash specificity and may reduce deduplication efficiency.
    static func nis(
        includeHeaders: Bool = false,
        headerWhitelist: Set<String>? = nil
    ) -> DefaultNISDuplicateStrategy {
        DefaultNISDuplicateStrategy(
            includeHeaders: includeHeaders,
            headerWhitelist: headerWhitelist
        )
    }
}

/// Default implementation of `NISDuplicateStrategy`.
///
/// Generates a stable hash for a request based on its most important identity components.
///
/// ## Identity rules
/// The following fields participate in hashing:
/// - HTTP method
/// - URL (absolute string)
/// - query items (order-insensitive)
/// - HTTP body (raw bytes)
/// - selected headers (optional)
///
/// ## Design goals
/// - deterministic
/// - safe (avoid false positives)
/// - reasonably fast
///
/// ## Important
/// - Headers are **excluded by default** to avoid unnecessary fragmentation.
/// - If your API relies on headers (e.g. Authorization, locale), enable them explicitly.
///
/// ## Example
/// ```swift
/// dispatcher.duplicateStrategy = DefaultNISDuplicateStrategy()
/// ```
public struct DefaultNISDuplicateStrategy: NISDuplicateIdentifying {

    // MARK: - Config

    /// Whether headers should be included into the hash.
    ///
    /// Default: `false`
    public let includeHeaders: Bool

    /// List of headers to include if `includeHeaders == true`.
    ///
    /// If empty → all headers are included.
    public let headerWhitelist: Set<String>?

    // MARK: - Init

    public init(
        includeHeaders: Bool = false,
        headerWhitelist: Set<String>? = nil
    ) {
        self.includeHeaders = includeHeaders
        self.headerWhitelist = headerWhitelist
    }

    // MARK: - Hashing

    public func uniqueHash(for request: URLRequest) -> Int? {
        guard let url = request.url else { return nil }

        var hasher = Hasher()

        // METHOD
        hasher.combine(request.httpMethod ?? "GET")

        // URL (normalized)
        hasher.combine(normalizedURLString(from: url))

        // BODY
        if let body = request.httpBody {
            hasher.combine(body.count)
            hasher.combine(body)
        }

        // HEADERS
        if includeHeaders {
            let headers = filteredHeaders(from: request.allHTTPHeaderFields)
            for key in headers.keys.sorted() {
                hasher.combine(key)
                hasher.combine(headers[key])
            }
        }

        return hasher.finalize()
    }
}

// MARK: - Helpers

private extension DefaultNISDuplicateStrategy {

    /// Normalizes URL to make query order irrelevant.
    func normalizedURLString(from url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        if let queryItems = components.queryItems {
            components.queryItems = queryItems.sorted { $0.name < $1.name }
        }

        return components.string ?? url.absoluteString
    }

    /// Filters headers according to whitelist rules.
    func filteredHeaders(from headers: [String: String]?) -> [String: String] {
        guard let headers else { return [:] }
        guard let headerWhitelist else { return headers }
        return headers.filter { headerWhitelist.contains($0.key) }
    }
}
