//
//  NISResponseDataTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `NISResponseData`.
final class NISResponseDataTests: XCTestCase {

    // MARK: - Test Methods

    func testNISResponseDataInitMethods() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://apple.com"))
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = ["Authorization": "Bearer token"]

        let body = Data("payload".utf8)
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json", "X-Test": "1"]
        )

        let plainResponse = URLResponse(
            url: url,
            mimeType: "text/plain",
            expectedContentLength: 5,
            textEncodingName: nil
        )

        func test(
            responseData: NISResponseData,
            expectation: NISResponseDataExpectation
        ) {
            switch expectation {
            case let .response(
                request,
                data,
                statusCode,
                hasHTTPResponse,
                headerValue
            ):
                XCTAssertEqual(responseData.request.url, request.url)
                XCTAssertEqual(responseData.request.allHTTPHeaderFields, request.allHTTPHeaderFields)
                XCTAssertEqual(responseData.data, data)
                XCTAssertEqual(responseData.statusCode, statusCode)
                XCTAssertEqual(responseData.httpResponse != nil, hasHTTPResponse)
                headerValue.map { XCTAssertEqual(responseData.headers?["X-Test"] as? String, $0) }
            }
        }

        // THEN
        test(
            responseData: .init(
                request: request,
                data: body,
                response: httpResponse
            ),
            expectation: .response(
                request: request,
                data: body,
                statusCode: 200,
                hasHTTPResponse: true,
                headerValue: "1"
            )
        )

        test(
            responseData: .init(
                request: request,
                data: nil,
                response: plainResponse
            ),
            expectation: .response(
                request: request,
                data: nil,
                statusCode: nil,
                hasHTTPResponse: false,
                headerValue: nil
            )
        )

        test(
            responseData: .init(
                request: request,
                data: nil,
                response: nil
            ),
            expectation: .response(
                request: request,
                data: nil,
                statusCode: nil,
                hasHTTPResponse: false,
                headerValue: nil
            )
        )
    }

    func testNISResponseDataEmptyProperty() {
        // GIVEN
        let empty = NISResponseData.empty
        
        // THEN
        XCTAssertEqual(empty.request.url?.absoluteString, "about:blank")
        XCTAssertNil(empty.data)
        XCTAssertNil(empty.response)
        XCTAssertNil(empty.httpResponse)
        XCTAssertNil(empty.statusCode)
        XCTAssertNil(empty.headers)
    }

    func testNISResponseDataRequestAndResponseWrappersPreserveRawValues() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://apple.com"))
        let request = URLRequest(url: url)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )
        let responseData = NISResponseData(
            request: request,
            data: nil,
            response: response
        )

        // THEN
        XCTAssertEqual(
            responseData.nisRequest.rawValue.url,
            request.url
        )
        XCTAssertEqual(
            (responseData.nisResponse.rawValue as? HTTPURLResponse)?.statusCode,
            204
        )
    }
}


// MARK: - Helpers

private extension NISResponseDataTests {

    enum NISResponseDataExpectation {
        case response(
            request: URLRequest,
            data: Data?,
            statusCode: Int?,
            hasHTTPResponse: Bool,
            headerValue: String?
        )
    }
}
