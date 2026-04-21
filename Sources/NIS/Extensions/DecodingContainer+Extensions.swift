//
//  DecodingContainer+Extensions.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

// More info:
// https://forums.swift.org/t/pitch-unkeyeddecodingcontainer-movenext-to-skip-items-in-deserialization/22151
// https://github.com/apple/swift/pull/23707
// https://github.com/apple/swift-evolution/pull/1012

private struct Empty: Decodable { }
private extension UnkeyedDecodingContainer {
    /// Advances the container by decoding and discarding a single element.
    ///
    /// This is used to recover from decoding failures in unkeyed containers
    /// (arrays) by skipping invalid items and continuing iteration.
    ///
    /// Internally decodes a placeholder type to move the container forward.
    mutating func skip() throws {
        _ = try decode(Empty.self)
    }
}

public extension UnkeyedDecodingContainer {
    /// Decodes an array of elements, skipping items that fail to decode.
    ///
    /// Unlike standard decoding, this method does not throw on individual element
    /// failures. Instead, it:
    /// - appends successfully decoded elements
    /// - skips invalid ones
    /// - continues processing the rest of the array
    ///
    /// - Important:
    ///   Failed elements are silently ignored. This may hide data inconsistencies.
    ///   Use only when partial data is acceptable.
    ///
    /// - Returns:
    ///   Array containing only successfully decoded elements.
    ///
    /// - Note:
    ///   If container state becomes corrupted (e.g. cannot skip), decoding stops
    ///   and an empty array is returned.
    mutating func decodeSafely<T: Decodable>(_ type: [T].Type) -> [T] {
        var elements = [T]()
        while !isAtEnd {
            if let element = try? decode(T.self) {
                elements.append(element)
            } else {
                do {
                    try skip()
                } catch {
                    return []
                }
            }
        }
        
        return elements
    }
    
    /// Convenience overload for `decodeSafely([T].self)`.
    mutating func decodeSafely<T: Decodable>() -> [T] {
        decodeSafely([T].self)
    }
}

public extension KeyedDecodingContainer {
    /// Decodes an array for the given key, skipping invalid elements.
    ///
    /// If the key is missing or not an array, returns an empty array.
    ///
    /// - Important:
    ///   Invalid elements are silently skipped.
    ///   Use only when partial decoding is acceptable.
    ///
    /// - Returns:
    ///   Array of successfully decoded elements, or empty array if key is missing.
    func decodeSafely<T: Decodable>(
        _ type: [T].Type,
        forKey key: KeyedDecodingContainer.Key
    ) -> [T] {
        guard var container = try? nestedUnkeyedContainer(forKey: key) else { return [] }
        return container.decodeSafely(type)
    }
    
    /// Convenience wrapper for `decode(_:forKey:)` with inferred type.
    ///
    /// Allows:
    /// ```swift
    /// let value: Model = try container.decode(forKey: .model)
    /// ```
    func decode<T: Decodable>(forKey key: K) throws -> T {
        try decode(T.self, forKey: key)
    }
    
    /// Attempts to decode a value using a primary key, falling back to an alternative key.
    ///
    /// Useful when backend responses may use different field names for the same value.
    ///
    /// - Returns:
    ///   Tuple containing:
    ///   - decoded value
    ///   - key that was successfully used
    ///
    /// - Throws:
    ///   If decoding fails for both keys.
    func decode<T: Decodable>(
        _ type: T.Type,
        forKey key: K,
        alternativeKey: K
    ) throws -> (value: T, key: K) {
        do {
            let value = try decode(T.self, forKey: key)
            return (value, key)
        } catch {
            let value = try decode(T.self, forKey: alternativeKey)
            return (value, alternativeKey)
        }
    }
    
    /// Convenience wrapper for `decodeIfPresent(_:forKey:)` with inferred type.
    func decodeIfPresent<T: Decodable>(forKey key: K) throws -> T? {
        try decodeIfPresent(T.self, forKey: key)
    }
}

public extension SingleValueDecodingContainer {
    /// Convenience wrapper for `decode(_:)` with inferred type.
    func decode<T: Decodable>() throws -> T {
        try decode(T.self)
    }
    
    /// Decodes a dictionary while safely skipping invalid values.
    ///
    /// Each value is decoded independently:
    /// - valid entries are included
    /// - invalid entries are ignored
    ///
    /// - Important:
    ///   Failed values are silently dropped.
    ///   Use only when partial data is acceptable.
    ///
    /// - Returns:
    ///   Dictionary containing only successfully decoded key-value pairs.
    func decodeSafely<Value: Decodable>() throws -> [String: Value] {
        try decode([String: DecodingContainer<Value>].self).compactMapValues(\.value)
    }
}

private struct DecodingContainer<Value: Decodable>: Decodable {
    let value: Value?
    
    init(from decoder: Decoder) throws {
        value = try? decoder.singleValueContainer().decode(Value.self)
    }
}
