//
//  NISErrorParserComposerTests.swift
//  NIS
//
//  Created by Andrew Matsota on 01.05.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `NISErrorParserComposer`
final class NISErrorParserComposerTests: XCTestCase {

    // MARK: - Test Methods

    func testInitStoresStackInOrder() {
        // GIVEN
        let first = MockParser()
        let second = MockParser()

        // WHEN
        let composer = NISErrorParserComposer([first, second])

        // THEN
        XCTAssertEqual(composer.stack.count, 2)
        XCTAssertTrue(composer.stack[0] as AnyObject === first)
        XCTAssertTrue(composer.stack[1] as AnyObject === second)
    }

    func testParseReturnsFirstNonNilError() {
        // GIVEN
        let composer = NISErrorParserComposer(
            [
                MockParser { _,_ in nil },
                .init { _,_ in TestError("B") },
                .init { _,_ in TestError("C") }
            ]
        )

        // WHEN
        let result = composer.parse(data: nil, response: nil)

        // THEN
        XCTAssertEqual(result as? TestError, TestError("B"))
    }

    func testParseDoesNotCallNextParsersAfterMatch() {
        // GIVEN
        var secondCalled = false
        var thirdCalled = false
        let composer = NISErrorParserComposer(
            [
                MockParser { _,_ in TestError("A") },
                .init { _,_ in
                    secondCalled = true
                    return TestError("B")
                },
                .init { _,_ in
                    thirdCalled = true
                    return TestError("C")
                }
            ]
        )

        // WHEN
        let result = composer.parse(data: nil, response: nil)

        // THEN
        XCTAssertEqual(result as? TestError, TestError("A"))
        XCTAssertFalse(secondCalled)
        XCTAssertFalse(thirdCalled)
    }

    func testParseReturnsNilWhenAllParsersFail() {
        // GIVEN
        let composer = NISErrorParserComposer([MockParser(), MockParser()])

        // WHEN
        let result = composer.parse(data: nil, response: nil)

        // THEN
        XCTAssertNil(result)
    }

    func testParsePassesDataAndResponseThrough() {
        // GIVEN
        var capturedData: Data?
        var capturedResponse: HTTPURLResponse?
        let composer = NISErrorParserComposer(
            [MockParser { capturedData = $0; capturedResponse = $1; return nil }]
        )
        let data = "test".data(using: .utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://apple.com")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        // WHEN
        _ = composer.parse(data: data, response: response)

        // THEN
        XCTAssertEqual(capturedData, data)
        XCTAssertEqual(capturedResponse?.statusCode, response?.statusCode)
    }
}

// MARK: - Private Helpers

private extension NISErrorParserComposerTests {
    
    struct TestError: Error, Equatable {
        let value: String
        init(_ value: String) { self.value = value }
    }

    final class MockParser: NISErrorParsable {

        private let block: (Data?, HTTPURLResponse?) -> Error?

        init(_ block: @escaping (Data?, HTTPURLResponse?) -> Error? = { _, _ in nil }) {
            self.block = block
        }

        func parse(data: Data?, response: HTTPURLResponse?) -> Error? {
            block(data, response)
        }
    }
}
