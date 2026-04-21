//
//  NISSecurityEvent.swift
//  NIS
//
//  Created by Andrew Matsota on 21.04.2026.
//

import Foundation

/// Security events emitted during request preparation and trust evaluation.
public enum NISSecurityEvent: Sendable {
    case preflightValidationStarted(url: URL?)
    case preflightValidationPassed(url: URL?)
    case proxyDetected(url: URL?)
    case localPinnedCertificatesValidated(count: Int)

    case systemTrustEvaluationStarted(host: String)
    case systemTrustEvaluationSucceeded(host: String)
    case systemTrustEvaluationFailed(host: String)

    case pinningValidationStarted(host: String)
    case pinningValidationSucceeded(host: String)
    case pinningValidationFailed(host: String)
    
    /// Generic event for security-related errors during evaluation.
    case securityError(Error, host: String)
}
