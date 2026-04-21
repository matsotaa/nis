//
//  Coding+Extensions.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

import Foundation

// MARK: - Date

public extension Date {

    /// Returns ISO8601 string using NIS default formatter.
    ///
    /// This format is stable and suitable for:
    /// - network payloads
    /// - analytics
    /// - logging
    var iso8601: String {
        ISO8601DateFormatter.default.string(from: self)
    }
}

// MARK: - JSONEncoder

public extension JSONEncoder {

    /// Default encoder used by NIS.
    ///
    /// Features:
    /// - Encodes `Date` as ISO8601 string (with fractional seconds)
    /// - Uses `.sortedKeys` to ensure deterministic output
    ///
    /// Deterministic output is important for:
    /// - request fingerprinting
    /// - caching
    /// - analytics comparison
    static let nis: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom {
            try $0.iso8601.encode(to: $1)
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    /// Encoder for backend endpoints requiring `"yyyy-MM-dd"` date format.
    ///
    /// - Important:
    ///   This format removes time components and may lead to data loss
    ///   (e.g. values normalized to start of day).
    ///
    /// - Use only when:
    ///   - backend explicitly requires `"yyyy-MM-dd"`
    ///
    /// - Do NOT use for:
    ///   - caching
    ///   - analytics
    ///   - internal persistence
    ///   - any logic relying on full date precision
    static let nisShortDate: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom {
            try $0.stringWithFormat("yyyy-MM-dd").encode(to: $1)
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

// MARK: - JSONDecoder

public extension JSONDecoder {

    /// Default decoder used by NIS.
    ///
    /// Supports multiple date formats to handle inconsistent backend responses:
    ///
    /// Parsing order:
    /// 1. Unix timestamp (seconds)
    /// 2. ISO8601 with fractional seconds
    /// 3. ISO8601 standard
    /// 4. ISO8601 (explicit fractional fallback)
    /// 5. `"yyyy-MM-dd"`
    ///
    /// - Note:
    ///   This decoder is intentionally flexible. If strict decoding is required,
    ///   consider using a custom `JSONDecoder`.
    static let nis: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            // Attempt timestamp parsing
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            
            // Attempt string-based parsing
            if let string = try? container.decode(String.self), let date = string.nisParsedDate {
                return date
            }

            // Build meaningful error context
            let path = decoder.codingPath.map(\.stringValue).joined(separator: ".")
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported date format at path '\(path)'. Expected ISO8601 string, yyyy-MM-dd, or timestamp.",
                    underlyingError: nil
                )
            )
        }
        return decoder
    }()

    /// Convenience wrapper for decoding.
    ///
    /// Allows:
    /// ```swift
    /// let model: Model = try JSONDecoder.nis.decode(from: data)
    /// ```
    func decode<T: Decodable>(from data: Data, _ type: T.Type = T.self) throws -> T {
        try decode(type, from: data)
    }
}

// MARK: - Decoder Helpers

private extension Decoder {

    /// Attempts to decode current value as `String`.
    ///
    /// Used internally for flexible date parsing.
    var nisDateString: String? {
        try? singleValueContainer().decode(String.self)
    }
}

// MARK: - String Date Parsing

private extension String {

    /// Attempts to parse string into `Date` using NIS-supported formats.
    ///
    /// Parsing order:
    /// 1. ISO8601 with fractional seconds
    /// 2. ISO8601 standard
    /// 3. ISO8601 (explicit fractional fallback)
    /// 4. `"yyyy-MM-dd"`
    var nisParsedDate: Date? {
        ISO8601DateFormatter.default.date(from: self)
        ?? ISO8601DateFormatter.internet.date(from: self)
        ?? ISO8601DateFormatter.internetWithFraction.date(from: self)
        ?? dateWithFormat("yyyy-MM-dd")
    }
}

// MARK: - ISO8601DateFormatter

/// Internal ISO8601 formatters used across NIS.
///
/// These instances are cached to avoid repeated allocations during encoding/decoding.
/// Marked as `nonisolated(unsafe)` to allow usage in concurrent contexts.
private extension ISO8601DateFormatter {

    /// Default formatter:
    /// - Internet date time
    /// - Fractional seconds
    /// - Full separators
    nonisolated(unsafe) static let `default`: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFractionalSeconds,
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        return formatter
    }()

    /// Standard internet date formatter (no fractional seconds).
    nonisolated(unsafe) static let internet: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Internet formatter with fractional seconds explicitly enabled.
    nonisolated(unsafe) static let internetWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
