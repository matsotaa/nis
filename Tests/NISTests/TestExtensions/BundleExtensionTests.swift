//
//  BundleExtensionTests.swift
//  NIS
//
//  Created by Andrew Matsota on 27.04.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `Bundle+Extension`
final class BundleExtensionTests: XCTestCase {
    
    // MARK: - Test Methods
    
    func testBundleMetadataAccessors() {
        XCTAssertEqual(
            Bundle.main.appVersion,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )

        XCTAssertEqual(
            Bundle.main.appBuild,
            Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
        )
    }
}
