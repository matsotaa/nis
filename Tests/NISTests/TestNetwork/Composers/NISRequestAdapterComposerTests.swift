//
//  NISRequestAdapterComposerTests.swift
//  NIS
//
//  Created by Andrew Matsota on 01.05.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `NISRequestAdapterComposer`
final class NISRequestAdapterComposerTests: XCTestCase {

    private var request: URLRequest!
    
    override func setUp() {
        request = URLRequest(url: URL(string: "https://apple.com")!)
    }
    
    override func tearDown() {
        request = nil
    }
    
    // MARK: - Test Methods

    func testInitStoresStackInOrder() {
        // GIVEN
        let first = MockAdapter()
        let second = MockAdapter()

        // WHEN
        let composer = NISRequestAdapterComposer([first, second])

        // THEN
        XCTAssertEqual(composer.stack.count, 2)
        XCTAssertTrue(composer.stack[0] as AnyObject === first)
        XCTAssertTrue(composer.stack[1] as AnyObject === second)
    }

    func testAdaptAppliesAllAdaptersInOrder() async throws {
        // GIVEN
        let composer = NISRequestAdapterComposer(
            [
                MockAdapter {
                    var request = $0
                    request.setValue("A", forHTTPHeaderField: "X-Step")
                    return request
                },
                .init {
                    var request = $0
                    let previous = request.value(forHTTPHeaderField: "X-Step") ?? ""
                    request.setValue(previous + "B", forHTTPHeaderField: "X-Step")
                    return request
                }
            ]
        )

        // WHEN
        let result = try await composer.adapt(request: request)

        // THEN
        XCTAssertEqual(result.value(forHTTPHeaderField: "X-Step"), "AB")
    }

    func testAdaptUsesOutputOfPreviousAdapter() async throws {
        // GIVEN
        let composer = NISRequestAdapterComposer(
            [
                MockAdapter {
                    var request = $0
                    request.setValue("token", forHTTPHeaderField: "Auth")
                    return request
                },
                .init {
                    var request = $0
                    let token = request.value(forHTTPHeaderField: "Auth")
                    request.setValue(token == "token" ? "ok" : "fail", forHTTPHeaderField: "Result")
                    return request
                }
            ]
        )

        // WHEN
        let result = try await composer.adapt(request: request)

        // THEN
        XCTAssertEqual(result.value(forHTTPHeaderField: "Result"), "ok")
    }

    func testAdaptReturnsSameRequestWhenStackIsEmpty() async throws {
        // GIVEN
        let composer = NISRequestAdapterComposer([])

        // WHEN
        let result = try await composer.adapt(request: request)

        // THEN
        XCTAssertEqual(result.url, request.url)
        XCTAssertEqual(result.allHTTPHeaderFields, request.allHTTPHeaderFields)
    }

    func testAdaptStopsExecutionWhenAdapterThrows() async {
        // GIVEN
        var secondCalled = false
        let composer = NISRequestAdapterComposer(
            [
                MockAdapter { _ in throw TestError() },
                .init { secondCalled = true; return $0 }
            ]
        )

        // WHEN
        do {
            _ = try await composer.adapt(request: request)
            XCTFail("Expected throw")
        } catch {
            // THEN
            XCTAssertFalse(secondCalled)
        }
    }

    func testAdaptPassesRequestThroughEachAdapter() async throws {
        // GIVEN
        var capturedRequest: URLRequest?
        let composer = NISRequestAdapterComposer(
            [MockAdapter { capturedRequest = $0; return $0 }]
        )

        // WHEN
        _ = try await composer.adapt(request: request)

        // THEN
        XCTAssertEqual(capturedRequest?.url, request.url)
    }
}

// MARK: - Private Helpers

private extension NISRequestAdapterComposerTests {
    
    struct TestError: Error { }

    final class MockAdapter: NISRequestAdaptable {
        private let block: (URLRequest) async throws -> URLRequest

        init(_ block: @escaping (URLRequest) async throws -> URLRequest = { $0 }) {
            self.block = block
        }

        func adapt(request: URLRequest) async throws -> URLRequest {
            try await block(request)
        }
    }
}
