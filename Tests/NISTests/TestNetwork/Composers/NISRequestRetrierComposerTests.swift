//
//  NISRequestRetrierComposerTests.swift
//  NIS
//
//  Created by Andrew Matsota on 01.05.2026.
//

import XCTest
@testable import NIS

/// Unit tests for `NISRequestRetrierComposer`
final class NISRequestRetrierComposerTests: XCTestCase {
    
    private var context: RetryContext!
    
    override func setUp() {
        let url = URL(string: "https://apple.com")!
        let request = URLRequest(url: url)
        context = RetryContext(
            request: request,
            error: .transport(.init(NSError(domain: "test", code: -1))),
            responseData: NISResponseData(
                request: request,
                data: nil,
                response: HTTPURLResponse(
                    url: url,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )
            ),
            retryCount: 1
        )
    }
    
    override func tearDown() {
        context = nil
    }
    
    // MARK: - Test Methods
    
    func testInitStoresStackInOrder() {
        // GIVEN
        let first = MockRetrier()
        let second = MockRetrier()
        
        // WHEN
        let composer = NISRequestRetrierComposer([first, second])
        
        // THEN
        XCTAssertEqual(composer.stack.count, 2)
        XCTAssertTrue(composer.stack[0] as AnyObject === first)
        XCTAssertTrue(composer.stack[1] as AnyObject === second)
    }
    
    func testShouldRetryReturnsFirstPositiveDecision() async {
        // GIVEN
        let composer = NISRequestRetrierComposer(
            [
                MockRetrier { _ in .init(shouldRetry: false) },
                .init { _ in .init(shouldRetry: true, delay: 1) },
                .init { _ in .init(shouldRetry: true, delay: 5) }
            ]
        )
        
        // WHEN
        let result = await composer.shouldRetry(
            request: context.request,
            error: context.error,
            responseData: context.responseData,
            retryCount: context.retryCount
        )
        
        // THEN
        XCTAssertTrue(result.shouldRetry)
        XCTAssertEqual(result.delay, 1)
    }
    
    func testShouldRetryDoesNotCallNextRetriersAfterPositiveDecision() async {
        // GIVEN
        var secondCalled = false
        var thirdCalled = false
        let composer = NISRequestRetrierComposer(
            [
                MockRetrier { _ in .init(shouldRetry: true, delay: 1) },
                .init { _ in
                    secondCalled = true
                    return .init(shouldRetry: true, delay: 2)
                },
                .init { _ in
                    thirdCalled = true
                    return .init(shouldRetry: true, delay: 3)
                }
            ]
        )
        
        // WHEN
        let result = await composer.shouldRetry(
            request: context.request,
            error: context.error,
            responseData: context.responseData,
            retryCount: context.retryCount
        )
        
        // THEN
        XCTAssertTrue(result.shouldRetry)
        XCTAssertEqual(result.delay, 1)
        XCTAssertFalse(secondCalled)
        XCTAssertFalse(thirdCalled)
    }
    
    func testShouldRetryReturnsFalseWhenAllRetriersDecline() async {
        // GIVEN
        let composer = NISRequestRetrierComposer(
            [MockRetrier { _ in .init(shouldRetry: false) }, .init { _ in .init(shouldRetry: false) }]
        )
        
        // WHEN
        let result = await composer.shouldRetry(
            request: context.request,
            error: context.error,
            responseData: context.responseData,
            retryCount: context.retryCount
        )
        
        // THEN
        XCTAssertFalse(result.shouldRetry)
        XCTAssertEqual(result.delay, 0)
    }
    
    func testShouldRetryReturnsFalseWhenEmpty() async {
        // GIVEN
        let composer = NISRequestRetrierComposer([])
        
        // WHEN
        let result = await composer.shouldRetry(
            request: context.request,
            error: context.error,
            responseData: context.responseData,
            retryCount: context.retryCount
        )
        
        // THEN
        XCTAssertFalse(result.shouldRetry)
        XCTAssertEqual(result.delay, 0)
    }
    
    func testShouldRetryPassesContextToRetriers() async {
        // GIVEN
        var capturedRequest: URLRequest?
        var capturedError: NISError?
        var capturedRetryCount: Int?
        
        let composer = NISRequestRetrierComposer(
            [
                MockRetrier {
                    capturedRequest = $0.request
                    capturedError = $0.error
                    capturedRetryCount = $0.retryCount
                    return .init(shouldRetry: false)
                }
            ]
        )
        
        // WHEN
        _ = await composer.shouldRetry(
            request: context.request,
            error: context.error,
            responseData: context.responseData,
            retryCount: context.retryCount
        )
        
        // THEN
        XCTAssertEqual(capturedRequest?.url, context.request.url)
        XCTAssertEqual(capturedError, context.error)
        XCTAssertEqual(capturedRetryCount, context.retryCount)
    }
}

// MARK: - Private Helpers

private extension NISRequestRetrierComposerTests {
    
    struct RetryContext {
        let request: URLRequest
        let error: NISError
        let responseData: NISResponseData
        let retryCount: Int
    }
    
    final class MockRetrier: NISRequestRetryable {
        private let block: (RetryContext) -> NISRetryDecision
        
        init(_ block: @escaping (RetryContext) -> NISRetryDecision = { _ in .init(shouldRetry: false) }) {
            self.block = block
        }
        
        func shouldRetry(
            request: URLRequest,
            error: NISError,
            responseData: NISResponseData,
            retryCount: Int
        ) async -> NISRetryDecision {
            block(
                .init(
                    request: request,
                    error: error,
                    responseData: responseData,
                    retryCount: retryCount
                )
            )
        }
    }
}
