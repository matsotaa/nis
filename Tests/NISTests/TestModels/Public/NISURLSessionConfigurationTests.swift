//
//  NISURLSessionConfigurationTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest
@testable import NIS

final class NISURLSessionConfigurationTests: XCTestCase {

    // MARK: - Tests

    func testNISURLSessionConfigurationMakeConfigurationMethod() {
        func test(
            configuration: NISURLSessionConfiguration,
            expectation: ConfigurationExpectation
        ) {
            let builtConfiguration = configuration.makeConfiguration()

            switch expectation {
            case let .nis(
                waitsForConnectivity,
                requestTimeout,
                resourceTimeout,
                containsHeaders
            ):
                XCTAssertEqual(builtConfiguration.waitsForConnectivity, waitsForConnectivity)
                XCTAssertEqual(builtConfiguration.timeoutIntervalForRequest, requestTimeout)
                XCTAssertEqual(builtConfiguration.timeoutIntervalForResource, resourceTimeout)
                if let headers = builtConfiguration.httpAdditionalHeaders, !headers.isEmpty {
                    containsHeaders.forEach { XCTAssertNotNil(headers[$0]) }
                    XCTAssertEqual(headers.count, 4)
                } else {
                    XCTFail("headers should not be nil or empty as per default implementation")
                }

            case let .custom(
                waitsForConnectivity,
                requestTimeout,
                resourceTimeout
            ):
                XCTAssertEqual(builtConfiguration.waitsForConnectivity, waitsForConnectivity )
                XCTAssertEqual(builtConfiguration.timeoutIntervalForRequest, requestTimeout )
                XCTAssertEqual(builtConfiguration.timeoutIntervalForResource, resourceTimeout)
                XCTAssertNil(builtConfiguration.httpAdditionalHeaders?.isEmpty)
            }
        }

        // THEN
        test(
            configuration: .nis,
            expectation: .nis(
                waitsForConnectivity: true,
                requestTimeout: 60,
                resourceTimeout: 120,
                containsHeaders: [
                    "X-OS",
                    "X-OS-Version",
                    "X-App-Version",
                    "X-App-Build"
                ]
            )
        )

        let customConfiguration = URLSessionConfiguration.ephemeral

        customConfiguration.waitsForConnectivity = false
        customConfiguration.timeoutIntervalForRequest = 15
        customConfiguration.timeoutIntervalForResource = 30

        test(
            configuration: .custom(configuration: customConfiguration),
            expectation: .custom(
                waitsForConnectivity: false,
                requestTimeout: 15,
                resourceTimeout: 30
            )
        )
    }
}


// MARK: - Helpers

private extension NISURLSessionConfigurationTests {

    enum ConfigurationExpectation {

        case nis(
            waitsForConnectivity: Bool,
            requestTimeout: TimeInterval,
            resourceTimeout: TimeInterval,
            containsHeaders: [String]
        )

        case custom(
            waitsForConnectivity: Bool,
            requestTimeout: TimeInterval,
            resourceTimeout: TimeInterval
        )
    }
}
