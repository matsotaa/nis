//
//  NISResponseData.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

/// A wrapper that makes `URLRequest` transferable across Swift concurrency domains.
///
/// `URLRequest` is not strictly `Sendable` due to internal mutability and bridging
/// with Objective-C. This wrapper explicitly marks it as `@unchecked Sendable`
/// to allow safe passage through actor boundaries in controlled contexts.
///
/// - Important:
///   This type does **not** make `URLRequest` inherently thread-safe.
///   It assumes the wrapped instance is not mutated after being passed across
///   concurrency boundaries.
///
/// - Design:
///   Keeps the `@unchecked Sendable` surface minimal and localized,
///   avoiding propagation of unsafe types throughout the SDK.
///
/// - Use case:
///   - request dispatching across actors
///   - logging / analytics pipelines
///   - deduplication systems
public struct NISSendableRequest: @unchecked Sendable {

    /// Original `URLRequest`.
    public let rawValue: URLRequest

    /// Wraps a `URLRequest` for cross-concurrency usage.
    public init(_ rawValue: URLRequest) {
        self.rawValue = rawValue
    }
}

/// A wrapper that makes `URLResponse` transferable across Swift concurrency domains.
///
/// Similar to `URLRequest`, `URLResponse` is not guaranteed to be `Sendable`.
/// This wrapper enables safe movement through concurrent flows under controlled usage.
///
/// - Important:
///   The underlying response must be treated as immutable once wrapped.
///
/// - Note:
///   Response is optional to reflect real transport scenarios
///   (e.g. failures before receiving response).
public struct NISSendableResponse: @unchecked Sendable {

    /// Original `URLResponse`.
    public let rawValue: URLResponse?

    /// Wraps a `URLResponse` for cross-concurrency usage.
    public init(_ rawValue: URLResponse?) {
        self.rawValue = rawValue
    }
}

// MARK: - Response Data

/// Raw transport payload produced by the networking layer.
///
/// `NISResponseData` represents the **unprocessed result** of a network request,
/// before any decoding or transformation into domain models.
///
/// It contains:
/// - original request
/// - raw response data
/// - response metadata
///
/// - Design:
///   This type is `Sendable` and intended to cross actor boundaries safely,
///   particularly in flows such as:
///   - request deduplication
///   - analytics pipelines
///   - logging / debugging layers
///
/// - Important:
///   This type does **not** guarantee that underlying Foundation objects are
///   thread-safe. It guarantees that they are **not mutated after capture**.
///
/// - Usage:
///   Prefer using this type instead of passing `URLRequest` / `URLResponse`
///   directly through concurrent systems.
public struct NISResponseData: Sendable {

    /// Sendable wrapper around the original request.
    public let nisRequest: NISSendableRequest

    /// Raw response body.
    ///
    /// May be `nil` in cases such as:
    /// - transport failure
    /// - empty response
    public let data: Data?

    /// Sendable wrapper around the original response.
    public let nisResponse: NISSendableResponse

    /// Creates a new response container.
    ///
    /// - Parameters:
    ///   - request: Original `URLRequest`
    ///   - data: Raw response data
    ///   - response: `URLResponse` received from transport layer
    public init(
        request: URLRequest,
        data: Data?,
        response: URLResponse?
    ) {
        self.nisRequest = NISSendableRequest(request)
        self.data = data
        self.nisResponse = NISSendableResponse(response)
    }

    /// Original request.
    ///
    /// Useful for:
    /// - debugging
    /// - logging
    /// - interceptors
    public var request: URLRequest {
        nisRequest.rawValue
    }

    /// Original response.
    ///
    /// Useful for:
    /// - debugging
    /// - logging
    /// - response inspection
    public var response: URLResponse? {
        nisResponse.rawValue
    }

    /// HTTP-specific response representation.
    ///
    /// - Returns: `HTTPURLResponse` if underlying response is HTTP-based.
    public var httpResponse: HTTPURLResponse? {
        response as? HTTPURLResponse
    }

    /// HTTP status code extracted from response.
    ///
    /// - Returns: Status code if available.
    public var statusCode: Int? {
        httpResponse?.statusCode
    }

    /// HTTP headers extracted from response.
    ///
    /// - Returns: Dictionary of header fields if available.
    public var headers: [AnyHashable: Any]? {
        httpResponse?.allHeaderFields
    }
}

public extension NISResponseData {
    
    /// Empty placeholder response data.
    ///
    /// Used when no actual transport data is available
    /// (e.g. early failure before request execution).
    ///
    /// - Note:
    ///   Uses a synthetic `about:blank` request to satisfy non-optional contract.
    static var empty: NISResponseData {
        NISResponseData(
            request: URLRequest(url: URL(string: "about:blank")!),
            data: nil,
            response: nil
        )
    }
}
