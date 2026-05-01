//
//  NISUnderlyingErrorTests.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import XCTest

@testable import NIS

final class NISUnderlyingErrorTests: XCTestCase {
    
    // MARK: - Test Methods
    
    func testNISUnderlyingErrorInit() {
        // GIVEN
        let error = NISUnderlyingError(URLError(.timedOut))
        
        // THEN
        XCTAssertTrue(error.rawValue is URLError)
        XCTAssertEqual((error.rawValue as NSError).code, URLError.timedOut.rawValue)
        XCTAssertEqual((error.rawValue as NSError).domain, NSURLErrorDomain)
    }
    
    func testMatchingMethod() {
        // GIVEN
        var error: Error = URLError(.timedOut)
        var nisError = NISUnderlyingError(URLError(.timedOut))
        
        // THEN
        XCTAssertTrue(nisError.matches(domain: NSURLErrorDomain, code: URLError.timedOut.rawValue))
        XCTAssertTrue(nisError.matches(error: error))
        
        // WHEN
        error = NISError.cancelled
        
        // THEN
        XCTAssertFalse(nisError.matches(error: error))
        
        // WHEN
        nisError = NISUnderlyingError(URLError(.cannotConnectToHost))
        
        // THEN
        XCTAssertTrue(nisError.matches(domain: NSURLErrorDomain, code: URLError.cannotConnectToHost.rawValue))
        XCTAssertTrue(nisError.matches(error: URLError(.cannotConnectToHost)))
    }
}
