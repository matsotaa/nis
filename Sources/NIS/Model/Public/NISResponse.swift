//
//  NISResponse.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// Conforms `NISResponse` to `Sendable` when its `Value` is `Sendable`.
///
/// This allows instances of `NISResponse` to safely cross concurrency
/// boundaries when used with Swift structured concurrency.
///
/// - Note: The contained `Value` must also conform to `Sendable` to
/// guarantee thread safety.
extension NISResponse: Sendable where Value: Sendable { }

/// A generic response container produced by the NIS networking pipeline.
///
/// `NISResponse` represents the full outcome of a dispatched request,
/// encapsulating:
/// - the decoded result (`Value`)
/// - raw transport data (`NISResponseData`)
/// - request-level metadata (e.g. duplication)
///
/// Designed to provide a **single, consistent abstraction** over:
/// - success / failure handling
/// - raw response inspection
/// - request deduplication signals
///
/// - Important:
///   `result` contains the high-level outcome, while `data` always reflects
///   the underlying transport layer state (even on failure when available).
///
/// - Note:
///   `isDuplicate` indicates that this response was produced from a repeated
///   request (e.g. deduplicated or replayed), not a fresh network call.
///
/// - Generic Parameter Value:
///   The successfully decoded response type.
public struct NISResponse<Value> {

    /// Result of request execution.
    ///
    /// - `.success(Value)` contains decoded model.
    /// - `.failure(NISError)` contains normalized error.
    public let result: Result<Value, NISError>
    
    /// Unwrapped `value` of result of request execution.
    public var value: Value? {
        guard case let .success(value) = result else { return nil }
        return value
    }
    
    /// Unwrapped `error` of result of request execution.
    public var error: NISError? {
        guard case let .failure(error) = result else { return nil }
        return error
    }

    /// Raw transport data associated with the request.
    ///
    /// Includes:
    /// - original `URLRequest`
    /// - raw response `Data`
    /// - `URLResponse`
    ///
    /// Useful for:
    /// - debugging
    /// - logging
    /// - analytics
    /// - custom parsing
    public let data: NISResponseData

    /// Indicates whether this response is a duplicate of a previous request.
    ///
    /// `true` means:
    /// - request was deduplicated
    /// - response may be reused or replayed
    ///
    /// `false` means:
    /// - response originates from a fresh network execution
    public private(set) var isDuplicate: Bool

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - result: Result of request execution.
    ///   - data: Raw response data.
    ///   - isDuplicate: Indicates whether response is duplicated.
    public init(
        result: Result<Value, NISError>,
        data: NISResponseData,
        isDuplicate: Bool = false
    ) {
        self.result = result
        self.data = data
        self.isDuplicate = isDuplicate
    }

    /// Convenience initializer for successful responses.
    ///
    /// - Parameters:
    ///   - value: Decoded response value.
    ///   - data: Raw response data.
    ///   - isDuplicate: Indicates whether response is duplicated.
    public init(
        success value: Value,
        data: NISResponseData,
        isDuplicate: Bool = false
    ) {
        self.init(
            result: .success(value),
            data: data,
            isDuplicate: isDuplicate
        )
    }

    /// Convenience initializer for failed responses.
    ///
    /// - Parameters:
    ///   - error: Normalized `NISError`.
    ///   - data: Raw response data (if available).
    ///
    /// - Note:
    ///   Uses `.empty` when no transport data exists.
    public init(
        error: NISError,
        data: NISResponseData = .empty
    ) {
        self.init(
            result: .failure(error),
            data: data,
            isDuplicate: false
        )
    }

    /// Marks response as duplicated.
    ///
    /// Intended to be used internally by the dispatcher layer.
    ///
    /// - Important:
    ///   Consumers should treat this flag as read-only metadata.
    public mutating func setIsDuplicate() {
        isDuplicate = true
    }
}

public extension NISResponse {
    
    /// Transforms the success value of the response while preserving all metadata.
    ///
    /// This method applies the provided transformation only to the successful
    /// result (`.success`) and leaves failures unchanged.
    ///
    /// ## Behavior
    /// - `.success(value)` → `.success(transform(value))`
    /// - `.failure(error)` → unchanged
    /// - `data` is preserved as-is
    ///
    /// ## Use Cases
    /// - Converting decoded models into domain models
    /// - Mapping responses to `Void` (e.g. ignoring payload)
    /// - Adapting response types without rebuilding the full response
    ///
    /// ## Example
    /// ```swift
    /// response.mapValue { userDTO in
    ///     User(dto: userDTO)
    /// }
    /// ```
    ///
    /// ```swift
    /// response.mapValue { _ in () } // Convert to Void
    /// ```
    ///
    /// - Parameter transform: A closure that transforms the success value.
    /// - Returns: A new `NISResponse` with the transformed value.
    func mapValue<U>(_ transform: (Value) -> U) -> NISResponse<U> {
        .init(
            result: result.map(transform),
            data: data
        )
    }
}
