//
//  NISSecurityError.swift
//  NIS
//
//  Created by Andrew Matsota on 21.04.2026.
//

import Foundation

/// Security-related errors thrown by `NISSecureURLSession`.
public enum NISSecurityError: Error, Sendable {
    /// A local pinned certificate could not be decoded or created.
    case invalidLocalCertificate

    /// Pinning mode was enabled with an empty certificate/key list.
    case missingPinnedCertificates

    /// System proxy configuration was detected for the request URL.
    case proxyDetected

    /// Server trust policy could not be configured.
    case invalidServerTrustPolicy
    
    /// Apple's system trust evaluation failed (e.g., expired or untrusted chain).
    case systemTrustEvaluationFailed(host: String)

    /// Server certificate chain does not match any pinned certificate.
    case pinnedCertificateMismatch
    
    /// Server public keys do not match any pinned SHA-256 hashes.
    case pinnedKeyMismatch
}
