//
//  NISUncheckedSendableBoxTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest
@testable import NIS

final class NISUncheckedSendableBoxTests: XCTestCase {

    func testInitStoresProvidedValue() {
        // GIVEN
        let value = "test"

        // WHEN
        let box = NISUncheckedSendableBox(value)

        // THEN
        XCTAssertEqual(box.value, value)
    }

    func testInitStoresReferenceTypeWithoutReplacingInstance() {
        // GIVEN
        let object = TestObject()

        // WHEN
        let box = NISUncheckedSendableBox(object)

        // THEN
        XCTAssertTrue(box.value === object)
    }
}

private final class TestObject { }
