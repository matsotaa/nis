//
//  InflightRequestStoreTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest

@testable import NIS

final class InflightRequestStoreTests: XCTestCase {

    private let key = 100

    // MARK: - Test Methods

    func testValueExecutesNewRequestWhenNoInflightOrCachedEntryExists() async {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()

        // WHEN
        let resolution = await store.value(for: key, policy: .disabled) {
            await counter.increment()
            return .success(.empty)
        }
        let callCount = await counter.value()
        
        // THEN
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(resolution.source, .new)
        XCTAssertFalse(resolution.isDuplicate)
        assertSuccess(resolution.result)
    }

    func testConcurrentIdenticalRequestsShareSingleInflightTask() async {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()
        let started = expectation(description: "Shared operation started")
        
        // WHEN
        async let first = store.value(for: key, policy: .disabled) {
            await counter.increment()
            started.fulfill()
            try? await Task.sleep(nanoseconds: 200_000_000)
            return .success(.empty)
        }
        await fulfillment(of: [started], timeout: 1)
        async let second = store.value(for: key, policy: .disabled) {
            XCTFail("Second request should join inflight task.")
            return .success(.empty)
        }

        let firstResolution = await first
        let secondResolution = await second
        let callCount = await counter.value()
        
        // THEN
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(firstResolution.source, .new)
        XCTAssertEqual(secondResolution.source, .inflight)
        XCTAssertTrue(secondResolution.isDuplicate)
        assertSuccess(firstResolution.result)
        assertSuccess(secondResolution.result)
    }

    func testDifferentRequestKeysDoNotShareInflightTasks() async {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()

        async let first = store.value(for: 1, policy: .disabled) {
            await counter.increment()
            return .success(.empty)
        }

        async let second = store.value(for: 2, policy: .disabled) {
            await counter.increment()
            return .success(.empty)
        }

        _ = await first
        _ = await second

        let callCount = await counter.value()
        
        // THEN
        XCTAssertEqual(callCount, 2)
    }
    
    func testValueReturnsCachedResponseWithinTTL() async {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()
        let policy: NISRecentResponseReusePolicy = .successOnly(ttl: 2)

        // WHEN
        _ = await store.value(for: key, policy: policy) {
            await counter.increment()
            return .success(.empty)
        }

        let cachedResolution = await store.value(for: key, policy: policy) {
            XCTFail("Operation should not execute when cache is valid.")
            return .success(.empty)
        }
        let callCount = await counter.value()
        
        // THEN
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(cachedResolution.source, .cache)
        XCTAssertTrue(cachedResolution.isDuplicate)
    }

    func testValueExecutesNewRequestAfterTTLExpires() async throws {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()
        let policy: NISRecentResponseReusePolicy = .successOnly(ttl: 0.15)

        // WHEN
        _ = await store.value(for: key, policy: policy) {
            await counter.increment()
            return .success(.empty)
        }

        try await Task.sleep(nanoseconds: 350_000_000)
        let resolution = await store.value(for: key, policy: policy) {
            await counter.increment()
            return .success(.empty)
        }
        let callCount = await counter.value()

        // THEN
        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(resolution.source, .new)
        XCTAssertFalse(resolution.isDuplicate)
    }

    func testFailureIsReusedWhenPolicyAllowsFailureReuse() async {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()
        let policy: NISRecentResponseReusePolicy = .successAndFailure(ttl: 2)

        // WHEN
        _ = await store.value(for: key, policy: policy) {
            await counter.increment()
            return .failure(.cancelled)
        }
        
        let cachedResolution = await store.value(for: key, policy: policy) {
            XCTFail("Failure should be reused from cache.")
            return .failure(.cancelled)
        }
        let callCount = await counter.value()

        // THEN
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(cachedResolution.source, .cache)
    }

    func testFailureIsNotCachedWhenPolicyDisallowsFailureReuse() async {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()
        let policy: NISRecentResponseReusePolicy = .successOnly(ttl: 2)

        _ = await store.value(for: key, policy: policy) {
            await counter.increment()
            return .failure(.cancelled)
        }

        // WHEN
        let resolution = await store.value(for: key, policy: policy) {
            await counter.increment()
            return .failure(.cancelled)
        }
        
        let callCount = await counter.value()

        // THEN
        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(resolution.source, .new)
    }

    func testNegativeTTLDisablesReuse() async {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()
        let policy: NISRecentResponseReusePolicy = .successOnly(ttl: -10)

        // WHEN
        _ = await store.value(for: key, policy: policy) {
            await counter.increment()
            return .success(.empty)
        }

        _ = await store.value(for: key, policy: policy) {
            await counter.increment()
            return .success(.empty)
        }

        let callCount = await counter.value()

        // THEN
        XCTAssertEqual(callCount, 2)
    }
    
    func testCancellingOneSubscriberDoesNotCancelSharedTask() async {
        // GIVEN
        let store = InflightRequestStore()
        let started = expectation(description: "Inflight operation started")

        let firstTask = Task {
            await store.value(for: key, policy: .disabled) {
                started.fulfill()
                try? await Task.sleep(nanoseconds: 300_000_000)
                return .success(.empty)
            }
        }

        await fulfillment(of: [started], timeout: 1)

        let secondTask = Task {
            await store.value(for: key, policy: .disabled) {
                XCTFail("Second request should join inflight task.")
                return .success(.empty)
            }
        }

        // WHEN
        firstTask.cancel()
        let secondResult = await secondTask.value

        // THEN
        XCTAssertEqual(secondResult.source, .inflight)
    }
    
    func testCancellingAllSubscribersRemovesInflightEntry() async {
        // GIVEN
        let store = InflightRequestStore()
        let counter = OperationCounter()
        let started = expectation(description: "Task started")
        
        let first = Task {
            await store.value(for: key, policy: .disabled) {
                await counter.increment()
                started.fulfill()

                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    XCTFail("Task should have been cancelled.")
                    return .success(.empty)

                } catch {
                    return .failure(.cancelled)
                }
            }
        }

        await fulfillment(of: [started], timeout: 1)

        let second = Task {
            await store.value(for: key, policy: .disabled) {
                XCTFail()
                return .success(.empty)
            }
        }

        // WHEN
        first.cancel()
        second.cancel()
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let freshResolution = await store.value(for: key, policy: .disabled) {
            await counter.increment()
            return .success(.empty)
        }
        
        let callCount = await counter.value()
        
        // THEN
        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(freshResolution.source, .new)
    }
}


// MARK: - Helpers

private extension InflightRequestStoreTests {

    func assertSuccess(_ result: Result<NISResponseData, NISError>) {
        switch result {
        case .success: break
        default: XCTFail("Expected success result.")
        }
    }
}

private actor OperationCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}
