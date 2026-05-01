//
//  NISResponseAnalyzerComposerTests.swift
//  NIS
//
//  Created by Andrew Matsota on 01.05.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `NISResponseAnalyzerComposer`
final class NISResponseAnalyzerComposerTests: XCTestCase {

    private let url = URL(string: "https://apple.com")!
    private var responseData: NISResponseData!
    
    override func setUp() {
        responseData = NISResponseData(
            request: URLRequest(url: url),
            data: "data".data(using: .utf8),
            response: HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
    }
    
    override func tearDown() {
        responseData = nil
    }
    
    // MARK: - Text Methods

    func testInitStoresStackInOrder() {
        // GIVEN
        let first = MockAnalyzer()
        let second = MockAnalyzer()

        // WHEN
        let composer = NISResponseAnalyzerComposer([first, second])

        // THEN
        XCTAssertEqual(composer.stack.count, 2)
        XCTAssertTrue(composer.stack[0] as AnyObject === first)
        XCTAssertTrue(composer.stack[1] as AnyObject === second)
    }

    func testAnalyzeCallsAllAnalyzersInOrder() {
        // GIVEN
        var callOrder: [String] = []
        let composer = NISResponseAnalyzerComposer(
            [
                MockAnalyzer { _ in callOrder.append("A") },
                .init { _ in callOrder.append("B") }
            ]
        )

        // WHEN
        composer.analyze(responseData: responseData)

        // THEN
        XCTAssertEqual(callOrder, ["A", "B"])
    }

    func testAnalyzeCallsAllAnalyzersEvenIfOneDoesNothing() {
        // GIVEN
        var called = false
        let composer = NISResponseAnalyzerComposer([MockAnalyzer(), .init { _ in called = true }])

        // WHEN
        composer.analyze(responseData: responseData)

        // THEN
        XCTAssertTrue(called)
    }

    func testAnalyzePassesSameResponseDataToAllAnalyzers() {
        // GIVEN
        var captured: [NISResponseData] = []
        let composer = NISResponseAnalyzerComposer(
            [MockAnalyzer { captured.append($0) }, .init { captured.append($0) }]
        )

        // WHEN
        composer.analyze(responseData: responseData)

        // THEN
        XCTAssertEqual(captured.count, 2)
        XCTAssertEqual(captured[0].request, responseData.request)
        XCTAssertEqual(captured[1].request, responseData.request)
        XCTAssertEqual(captured[0].response, responseData.response)
        XCTAssertEqual(captured[1].response, responseData.response)
        XCTAssertEqual(captured[0].data, responseData.data)
        XCTAssertEqual(captured[1].data, responseData.data)
    }
}

// MARK: - Helpers

private extension NISResponseAnalyzerComposerTests {
    
    final class MockAnalyzer: NISResponseDataAnalyzable {
        private let block: (NISResponseData) -> Void

        init(_ block: @escaping (NISResponseData) -> Void = { _ in }) {
            self.block = block
        }

        func analyze(responseData: NISResponseData) {
            block(responseData)
        }
    }
}
