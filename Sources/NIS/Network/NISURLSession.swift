//
//  NISURLSession.swift
//  NIS
//
//  Created by Andrew Matsota on 07.04.2026.
//

import Foundation

public typealias HTTPHeaders = [String: String]

/// Concrete app-ready session built on top of `SecureURLSession`.
///
/// This class provides a default configuration and a default set of headers,
/// but still supports SSL pinning and proxy validation inherited from the base class.
///
/// Use this session as the default transport for SDKs or app-level networking.
public final class NISURLSession: NISSecureURLSession, @unchecked Sendable {
    
    /// Creates a secure session with default configuration and optional security config.
    ///
    /// - Parameters:
    ///   - configuration: Session configuration. Defaults to `nis()` which makes default configuration with default http headers, which are: **X-OS**, **X-OS-Version**, **X-App-Version**, **X-App-Build**
    ///   - qualityOfService: Delegate queue QoS.
    ///   - securityConfig: Optional SSL security configuration.
    public convenience init(
        configuration: NISURLSessionConfiguration = .nis,
        qualityOfService: QualityOfService = .utility,
        securityConfig: NISSSL.SecurityConfig = .init(trustMode: .disabled)
    ) {
        self.init(
            configuration: configuration.makeConfiguration(),
            qualityOfService: qualityOfService,
            securityConfig: securityConfig
        )
    }
}
