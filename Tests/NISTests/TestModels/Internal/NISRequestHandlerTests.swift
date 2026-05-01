//
//  NISRequestHandlerTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest

@testable import NIS

final class NISRequestHandlerTests: XCTestCase {

    func testCancelCancelsUnderlyingTask() async {
        // GIVEN
        let cancelled = expectation(description: "Task cancelled")

        let task = Task {
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch is CancellationError {
                cancelled.fulfill()
            } catch {
                XCTFail("Unexpected error")
            }
        }

        let handler = NISRequestHandler(task: task)

        // WHEN
        handler.cancel()

        // THEN
        await fulfillment(of: [cancelled], timeout: 1)
        XCTAssertTrue(task.isCancelled)
    }
}
