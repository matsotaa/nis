//
//  NISURLSessionConfigurationContainer.swift
//  NIS
//
//  Created by Andrew Matsota on 08.04.2026.
//

import Foundation

public enum NISURLSessionConfiguration {
    case nis
    case custom(configuration: URLSessionConfiguration)
}

public extension NISURLSessionConfiguration {
    /// Creates the URL session configuration.
    ///
    /// Adds SDK/app-level HTTP headers useful for diagnostics and analytics.
    func makeConfiguration() -> URLSessionConfiguration {
        switch self {
        case .nis:
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = defaultHTTPHeaders
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 120
            return configuration
            
        case .custom(let configuration):
            return configuration
        }
    }
}

private extension NISURLSessionConfiguration {
    
    var defaultHTTPHeaders: HTTPHeaders {
        [
            "X-OS": currentOSName,
            "X-OS-Version": ProcessInfo.processInfo.operatingSystemVersionString,
            "X-App-Version": Bundle.main.appVersion,
            "X-App-Build": Bundle.main.appBuild
        ].compactMapValues { $0 }
    }
    
    var currentOSName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(Linux)
        return "Linux"
        #else
        return "Unknown"
        #endif
    }
}
