//
//  NISErrorInterceptorComposerTests.swift
//  NIS
//
//  Created by Andrew Matsota on 01.05.2026.
//

import XCTest
@testable import NIS

/// Unit tests for `NISErrorInterceptorComposer`
final class NISErrorInterceptorComposerTests: XCTestCase {

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
        let first = MockInterceptor()
        let second = MockInterceptor()

        // WHEN
        let composer = NISErrorInterceptorComposer([first, second])

        // THEN
        XCTAssertEqual(composer.stack.count, 2)
        XCTAssertTrue(composer.stack[0] as AnyObject === first)
        XCTAssertTrue(composer.stack[1] as AnyObject === second)
    }

    func testInterceptErrorPassesThroughAllInterceptorsInOrder() async {
        // GIVEN
        let composer = NISErrorInterceptorComposer(
            [
                MockInterceptor { _ in .emptyResponse },
                .init { _ in .invalidResponse }
            ]
        )

        // WHEN
        let result = await composer.interceptError(error: .cancelled, request: request, response: nil, data: nil)

        // THEN
        XCTAssertEqual(result, .invalidResponse)
    }

    func testInterceptErrorUsesOutputOfPreviousInterceptor() async {
        // GIVEN
        let composer = NISErrorInterceptorComposer(
            [
                MockInterceptor { _ in .cancelled },
                .init { _ in .emptyResponse },
                .init { $0.error == .emptyResponse ? .invalidResponse : $0.error }
            ]
        )

        // WHEN
        let result = await composer.interceptError(error: .cancelled, request: request, response: nil, data: nil)

        // THEN
        XCTAssertEqual(result, .invalidResponse)
    }

    func testInterceptErrorReturnsSameErrorWhenStackIsEmpty() async {
        // GIVEN
        let composer = NISErrorInterceptorComposer([])

        // WHEN
        let result = await composer.interceptError(error: .cancelled, request: request, response: nil, data: nil)

        // THEN
        XCTAssertEqual(result, .cancelled)
    }
    
    func testInterceptErrorPassesRequestResponseDataThrough() async {
        // GIVEN
        var capturedRequest: URLRequest?
        var capturedResponse: HTTPURLResponse?
        var capturedData: Data?
        let composer = NISErrorInterceptorComposer(
            [
                MockInterceptor {
                    capturedRequest = $0.request
                    capturedResponse = $0.response
                    capturedData = $0.data
                    return $0.error
                }
            ]
        )
        
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
        let data = "test".data(using: .utf8)

        // WHEN
        _ = await composer.interceptError(error: .cancelled, request: request, response: response, data: data)

        // THEN
        XCTAssertEqual(capturedRequest?.url, request.url)
        XCTAssertEqual(capturedResponse?.statusCode, response?.statusCode)
        XCTAssertEqual(capturedData, data)
    }
}

// MARK: - Private Helpers

private extension NISErrorInterceptorComposerTests {
    
    final class MockInterceptor: NISDispatcherErrorInterceptable {
        private let perform: (
            (
                error: NISError,
                request: URLRequest,
                response: HTTPURLResponse?,
                data: Data?
            )
        ) -> NISError

        init(
            perform: @escaping (
                (
                    error: NISError,
                    request: URLRequest,
                    response: HTTPURLResponse?,
                    data: Data?
                )
            ) -> NISError = { $0.error }
        ) {
            self.perform = perform
        }

        func interceptError(
            error: NISError,
            request: URLRequest,
            response: HTTPURLResponse?,
            data: Data?
        ) async -> NISError {
            perform((error, request, response, data))
        }
    }
}
