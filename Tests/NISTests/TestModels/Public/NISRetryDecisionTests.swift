//
//  NISRetryDecisionTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `NISRetryDecision`.
final class NISRetryDecisionTests: XCTestCase {

    // MARK: - Tests Methods

    func testNISRetryDecisionInitMethods() {
        // GIVEN
        func test(decision: NISRetryDecision, expectation: NISRetryDecisionExpectation) {
            switch expectation {
            case let .decision(shouldRetry, delay):
                XCTAssertEqual(decision.shouldRetry, shouldRetry)
                XCTAssertEqual(decision.delay, delay)
            }
        }

        // THEN
        test(
            decision: .init(shouldRetry: true),
            expectation: .decision(shouldRetry: true, delay: 0)
        )
        test(
            decision: .init(shouldRetry: true, delay: 2),
            expectation: .decision(shouldRetry: true, delay: 2)
        )
        test(
            decision: .init(shouldRetry: false, delay: 5),
            expectation: .decision(shouldRetry: false, delay: 5)
        )
    }

    func testNISRetryDecisionDoNotRetryProperty() {
        // GIVEN
        let decision = NISRetryDecision.doNotRetry

        // THEN
        XCTAssertFalse(decision.shouldRetry)
        XCTAssertEqual(decision.delay, 0)
    }

    func testNISRetryDecisionAcceptsNegativeDelayAsPassedThroughValue() {
        // GIVEN
        let decision = NISRetryDecision(shouldRetry: true, delay: -1)

        // THEN
        XCTAssertTrue(decision.shouldRetry)
        XCTAssertEqual(decision.delay, -1)
    }

    func testNISRetryDecisionZeroDelayRepresentsImmediateRetry() {
        // GIVEN
        let decision = NISRetryDecision(shouldRetry: true, delay: 0)

        // THEN
        XCTAssertTrue(decision.shouldRetry)
        XCTAssertEqual(decision.delay, 0)
    }
}


// MARK: - Helpers

private extension NISRetryDecisionTests {

    enum NISRetryDecisionExpectation {
        case decision(
            shouldRetry: Bool,
            delay: TimeInterval
        )
    }
}
