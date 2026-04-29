//
//  NISResponseTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `NISResponse` model
final class NISResponseTests: XCTestCase {
    
    // MARK: - Test Methods
    
    func testNISResponseInitMethods() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "https://www.apple.com"))
        let header = ["Any-Header": "To make difference"]
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = header
        
        let emptyResult: NISEmptyResult = .init()
        let mockResponseData = NISResponseData(request: urlRequest, data: Data(), response: URLResponse())
        func test(response: NISResponse<NISEmptyResult>, expectation: NISResponseExpectation) {
            switch expectation {
            case .response(let result, let data, let isDuplicated):
                XCTAssertEqual(response.isDuplicate, isDuplicated)
                XCTAssertEqual(response.value, result.value)
                XCTAssertEqual(response.error, result.error)
                XCTAssertEqual(response.data.data, data.data)
                XCTAssertEqual(response.data.request, data.request)
                XCTAssertEqual(response.data.nisResponse.rawValue, data.nisResponse.rawValue)
            }
        }
        
        // THEN
        test(
            response: .init(result: .success(.init()), data: mockResponseData, isDuplicate: true),
            expectation: .response(result: .success(.init()), data: mockResponseData, duplicated: true)
        )
        test(
            response: .init(result: .failure(.cancelled), data: .empty),
            expectation: .response(result: .failure(.cancelled), data: .empty, duplicated: false)
        )
        test(
            response: .init(success: emptyResult, data: .empty, isDuplicate: true),
            expectation: .response(result: .success(emptyResult), data: .empty, duplicated: true)
        )
        test(
            response: .init(success: emptyResult, data: mockResponseData),
            expectation: .response(result: .success(emptyResult), data: mockResponseData, duplicated: false)
        )
        test(
            response: .init(error: .cancelled, data: mockResponseData),
            expectation: .response(result: .failure(.cancelled), data: mockResponseData, duplicated: false)
        )
        test(
            response: .init(error: .emptyResponse),
            expectation: .response(result: .failure(.emptyResponse), data: .empty, duplicated: false)
        )
    }
    
    func testNISResponseSetDuplicatedMethod() {
        // GIVEN
        var response = NISResponse<NISEmptyResult>(error: .cancelled)
        
        // THEN
        XCTAssertFalse(response.isDuplicate)
        
        // WHEN
        response.setIsDuplicate()
        
        // THEN
        XCTAssertTrue(response.isDuplicate)
    }
    
    func testMapValueCallsTransformOnceForSuccess() {
        // GIVEN
        var callCount = 0
        let response = NISResponse(success: 10, data: .empty)

        // WHEN
        let mapped = response.mapValue { value in
            callCount += 1
            return value * 2
        }

        // THEN
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(mapped.value, 20)
    }
    
    func testMapValueDoesNotCallTransformForFailure() {
        // GIVEN
        var wasCalled = false
        let response = NISResponse<Int>(error: .cancelled)
        
        // WHEN
        let mapped = response.mapValue { value in
            wasCalled = true
            return value * 2
        }

        // THEN
        XCTAssertFalse(wasCalled)
        XCTAssertEqual(mapped.error, .cancelled)
        XCTAssertNil(mapped.value)
    }
}

// MARK: - Private Helpers

private extension NISResponseTests {
    
    enum NISResponseExpectation {
        case response(
            result: Result<NISEmptyResult, NISError>,
            data: NISResponseData,
            duplicated: Bool
        )
    }
}
