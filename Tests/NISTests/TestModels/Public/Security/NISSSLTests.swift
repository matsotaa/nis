//
//  NISSSLTests.swift
//  NIS
//
//  Created by Andrew Matsota on 27.04.2026.
//

import XCTest
@testable import NIS

/// Unit tests for `NISSSL`
/// These tests intentionally validate initialization contracts
/// for public security configuration types. For SDK models,
/// this helps catch accidental behavioral regressions as APIs evolve.
final class NISSSLTests: XCTestCase {

    // MARK: - Certificate

    func testNISSSLCertificateHashableEqualityAndInit() {
        // GIVEN
        let lhs = NISSSL.Certificate(rawValue: "abc")
        let rhs = NISSSL.Certificate(rawValue: "abc")

        // THEN
        XCTAssertEqual(lhs, rhs)
        XCTAssertEqual(lhs.rawValue, "abc")
        XCTAssertEqual(Set([lhs, rhs]).count, 1)
    }

    func testNISSSLSecurityConfigDefaultInitProperties() {
        // GIVEN
        let config = NISSSL.SecurityConfig(trustMode: .disabled)

        // THEN
        guard case .disabled = config.trustMode else { return XCTFail() }
        XCTAssertFalse(config.blocksProxies)
    }

    func testNISSSLTrustModeDefaultInitProperties() {
        // GIVEN
        let mode: NISSSL.TrustMode = .pinnedCertificates(certificates: [])

        // WHEN
        guard case .pinnedCertificates(
            _,
            let validatesHost,
            let validatesCertificateChain
        ) = mode else {
            return XCTFail()
        }
        
        // THEN
        XCTAssertTrue(validatesHost)
        XCTAssertTrue(validatesCertificateChain)
    }
}
