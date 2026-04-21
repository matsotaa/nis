//
//  Bundle+Extensions.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

public extension Bundle {
    
    /// The user-facing app version (`CFBundleShortVersionString`).
    ///
    /// Typically corresponds to the marketing version shown in the App Store
    /// (e.g. `"1.2.0"`).
    ///
    /// - Returns: Version string if present in `Info.plist`, otherwise `nil`.
    var appVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// The internal build number (`CFBundleVersion`).
    ///
    /// Used for build tracking and incremented on each release or CI build
    /// (e.g. `"42"`).
    ///
    /// - Returns: Build number string if present in `Info.plist`, otherwise `nil`.
    var appBuild: String? {
        object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
    }
}
