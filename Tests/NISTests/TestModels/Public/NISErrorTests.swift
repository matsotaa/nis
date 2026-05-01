//
//  NISErrorTests.swift
//  NIS
//
//  Created by Andrew Matsota on 27.04.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `NISError`
final class NISErrorTests: XCTestCase {
    
    // MARK: - Test Methods
    
    func testNISErrorWrappersAndNISUnderlyingErrorInit() {
        // GIVEN
        let nsError = NSError(domain: "Error for tests", code: 500)
        func test(error: NISError, testWrapper: NISErrorTestWrapper) {
            XCTAssertEqual(error.testWrapper, testWrapper)
            switch error {
            case .decoding(let error), .transport(let error), .other(let error):
                XCTAssertEqual(nsError, error.rawValue as NSError)
                
            default: XCTFail("Init wrappes are: decoding, transport, other")
            }
        }
        
        // THEN
        test(error: .decoding(nsError), testWrapper: .decoding)
        test(error: .transport(nsError), testWrapper: .transport)
        test(error: .other(nsError), testWrapper: .other)
    }
    
    func testNISErrorEquatable() {
        XCTAssertEqual(
            NISError.cancelled,
            .cancelled
        )

        XCTAssertEqual(
            NISError.emptyResponse,
            .emptyResponse
        )

        XCTAssertNotEqual(
            NISError.cancelled,
            .emptyResponse
        )

        XCTAssertEqual(
            NISError.decoding(
                NSError(domain: "test", code: 1)
            ),
            NISError.decoding(
                NSError(domain: "other", code: 999)
            )
        )

        XCTAssertEqual(
            NISError.transport(
                URLError(.timedOut)
            ),
            NISError.transport(
                URLError(.cannotConnectToHost)
            )
        )

        XCTAssertNotEqual(
            NISError.transport(
                URLError(.timedOut)
            ),
            NISError.decoding(
                URLError(.timedOut)
            )
        )

        XCTAssertEqual(
            NISError.invalidStatusCode(
                404,
                Data("body".utf8),
                nil
            ),
            NISError.invalidStatusCode(
                404,
                Data("body".utf8),
                nil
            )
        )

        XCTAssertNotEqual(
            NISError.invalidStatusCode(
                404,
                nil,
                nil
            ),
            NISError.invalidStatusCode(
                500,
                nil,
                nil
            )
        )
        
        XCTAssertNotEqual(
            NISError.invalidStatusCode(
                500,
                Data("body".utf8),
                nil
            ),
            NISError.invalidStatusCode(
                500,
                Data("body-1".utf8),
                nil
            )
        )
    }
}

// MARK: - Private Helpers

private enum NISErrorTestWrapper {
    case decoding, transport, other
}

private extension NISError {
    
    var testWrapper: NISErrorTestWrapper? {
        switch self {
        case .decoding: .decoding
        case .transport: .transport
        case .other: .other
        default: nil
        }
    }
}
