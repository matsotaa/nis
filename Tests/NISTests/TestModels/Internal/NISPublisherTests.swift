//
//  NISPublisherTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest
import Combine

@testable import NIS

final class NISPublisherTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Test Methods

    func testPublisherEmitsSingleValueAndFinishes() {
        // GIVEN
        let valueReceived = expectation(description: "Value received")
        let finished = expectation(description: "Finished")
        let dispatcher = MockDispatcher(result: .init(success: TestModel(value: "ok"), data: .empty))
        let publisher = makePublisher(dispatcher: dispatcher)
        var valuesCount = 0

        // WHEN
        publisher
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        finished.fulfill()
                    }
                },
                receiveValue: { response in
                    valuesCount += 1
                    XCTAssertEqual(response.value?.value, "ok")
                    valueReceived.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [valueReceived, finished], timeout: 1)

        // THEN
        XCTAssertEqual(valuesCount, 1)
        XCTAssertEqual(dispatcher.requestCallCount, 1)
    }

    func testPublisherDoesNotEmitAfterCancellation() {
        // GIVEN
        let noValue = expectation(description: "No value")
        noValue.isInverted = true

        let noCompletion = expectation(description: "No completion")
        noCompletion.isInverted = true

        let started = expectation(description: "Request started")
        let dispatcher = MockDispatcher(
            delayNanoseconds: 300_000_000,
            onRequestStarted: { started.fulfill() },
            result: .init(success: TestModel(value: "late"), data: .empty)
        )

        let publisher = makePublisher(dispatcher: dispatcher)

        var cancellable: AnyCancellable?

        // WHEN
        cancellable = publisher.sink(
            receiveCompletion: { _ in noCompletion.fulfill() },
            receiveValue: { _ in noValue.fulfill() }
        )

        wait(for: [started], timeout: 1)

        cancellable?.cancel()
        
        wait(for: [noValue, noCompletion], timeout: 0.5)

        // THEN
        XCTAssertEqual(dispatcher.requestCallCount, 1)
    }

    func testPublisherEmitsFailureWrappedResponse() {
        // GIVEN
        let received = expectation(description: "Failure response")
        let dispatcher = MockDispatcher(result: .init(error: .cancelled))
        let publisher = makePublisher(dispatcher: dispatcher)

        // WHEN
        publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { response in
                    XCTAssertEqual(response.error, .cancelled)
                    received.fulfill()
                }
            )
            .store(in: &cancellables)

        // THEN
        wait(for: [received], timeout: 1)
    }

    func testPublisherRequestsDispatcherOnlyOnce() {
        // GIVEN
        let finished = expectation(description: "Finished")
        let dispatcher = MockDispatcher(result: .init(success: TestModel(value: "once"), data: .empty))
        let publisher = makePublisher(dispatcher: dispatcher)

        // WHEN
        publisher
            .sink(
                receiveCompletion: { _ in finished.fulfill() },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        wait(for: [finished], timeout: 1)

        // THEN
        XCTAssertEqual(dispatcher.requestCallCount, 1)
    }
    
    func testCancelPropagatesToUnderlyingTask() {
        // GIVEN
        let cancelled = expectation(description: "Task cancelled")
        var didCancelTask = false

        let dispatcher = MockDispatcher(
            delayNanoseconds: 3_000_000_000,
            onRequestFinished: {
                didCancelTask = true
                cancelled.fulfill()
            },
            result: .init(error: .cancelled)
        )

        // WHEN
        let cancellable = makePublisher(dispatcher: dispatcher)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in XCTFail("Should not emit value") }
            )

        cancellable.cancel()

        wait(for: [cancelled], timeout: 1)

        // THEN
        XCTAssertTrue(didCancelTask)
    }
}


// MARK: - Helpers

private extension NISPublisherTests {

    func makePublisher(
        dispatcher: NISRequestDispatching
    ) -> NISPublisher<TestModel> {
        NISPublisher(
            dispatcher: dispatcher,
            request: URLRequest(url: URL(string: "https://apple.com")!),
            decoder: .init()
        )
    }
}

private struct TestModel: Decodable, Equatable {
    let value: String
}

// MARK: - Mock

private final class MockDispatcher: NISRequestDispatching {

    var shouldCancelRequest = false
    
    private let result: NISResponse<TestModel>
    private let delayNanoseconds: UInt64?
    private let onRequestStarted: (() -> Void)?
    private let onRequestFinished: (() -> Void)?
    
    private(set) var requestCallCount = 0

    init(
        delayNanoseconds: UInt64? = nil,
        onRequestStarted: (() -> Void)? = nil,
        onRequestFinished: (() -> Void)? = nil,
        result: NISResponse<TestModel>
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.onRequestStarted = onRequestStarted
        self.onRequestFinished = onRequestFinished
        self.result = result
    }

    func request<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type,
        decoder: JSONDecoder
    ) async -> NISResponse<T> {
        requestCallCount += 1
        onRequestStarted?()
        if let delayNanoseconds {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        onRequestFinished?()
        
        return result as! NISResponse<T>
    }
}
