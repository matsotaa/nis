//
//  NISRecentResponseReusePolicyTests.swift
//  NIS
//
//  Created by Andrew Matsota on 27.04.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `NISRecentResponseReusePolicy`
final class NISRecentResponseReusePolicyTests: XCTestCase {
    
    // MARK: - Test Methods
    
    func testCases() {
        // GIVEN
        func test(_ policy: NISRecentResponseReusePolicy, expectedValue: TimeInterval?) {
            guard let ttl = policy.ttl else { return XCTAssertNil(policy.ttl) }
            XCTAssertEqual(ttl, expectedValue)
        }
        
        // THEN
        test(.disabled, expectedValue: nil)
        test(.successOnly(ttl: 1), expectedValue: 1)
        test(.successOnly(ttl: -1), expectedValue: 0)
        test(.successAndFailure(ttl: 2), expectedValue: 2)
        test(.successAndFailure(ttl: -2), expectedValue: 0)
    }
    
    func testAllowsSuccess() {
        // GIVEN
        func test(_ policy: NISRecentResponseReusePolicy, expectedValue: Bool) {
            XCTAssertEqual(policy.allowsSuccess, expectedValue)
        }
        
        // THEN
        test(.disabled, expectedValue: false)
        test(.successOnly(ttl: 1), expectedValue: true)
        test(.successOnly(ttl: -1), expectedValue: true)
        test(.successAndFailure(ttl: 2), expectedValue: true)
        test(.successAndFailure(ttl: -2), expectedValue: true)
    }
    
    func testAllowsFailure() {
        // GIVEN
        func test(_ policy: NISRecentResponseReusePolicy, expectedValue: Bool) {
            XCTAssertEqual(policy.allowsFailure, expectedValue)
        }
        
        // THEN
        test(.disabled, expectedValue: false)
        test(.successOnly(ttl: 1), expectedValue: false)
        test(.successOnly(ttl: -1), expectedValue: false)
        test(.successAndFailure(ttl: 2), expectedValue: true)
        test(.successAndFailure(ttl: -2), expectedValue: true)
    }
    
    func testIsEnabled() {
        // GIVEN
        func test(_ policy: NISRecentResponseReusePolicy, expectedValue: Bool) {
            XCTAssertEqual(policy.isEnabled, expectedValue)
        }
        
        // THEN
        test(.disabled, expectedValue: false)
        test(.successOnly(ttl: 1), expectedValue: true)
        test(.successOnly(ttl: 0), expectedValue: false)
        test(.successOnly(ttl: -1), expectedValue: false)
        test(.successAndFailure(ttl: 2), expectedValue: true)
        test(.successAndFailure(ttl: 0), expectedValue: false)
        test(.successAndFailure(ttl: -2), expectedValue: false)
    }
}
