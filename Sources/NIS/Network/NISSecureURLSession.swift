//
//  NISSecureURLSession.swift
//  NIS
//
//  Created by Andrew Matsota on 21.04.2026.
//

import Foundation
import Security
import CFNetwork
import CryptoKit

// MARK: - Public Secure Session

/// `URLSession` wrapper that provides:
/// - optional proxy blocking
/// - system trust evaluation
/// - optional certificate pinning
/// - optional public key pinning
/// - async/await API
///
/// ## Design
/// Security responsibilities are intentionally split into dedicated components:
/// - preflight security pipeline
/// - proxy validator
/// - local certificate validator
/// - server trust evaluator
///
/// ## Important
/// - If `securityConfig` is `nil`, the session behaves like a regular `URLSession`.
/// - If `.disabled` trust mode is used, trust handling falls back to default `URLSession` behavior.
/// - System trust evaluation already validates certificate expiration and chain validity,
///   so this implementation does not duplicate that logic manually.
public class NISSecureURLSession: NSObject, AnyNISURLSession, @unchecked Sendable {

    // MARK: - Private Storage

    private enum SessionStorage {
        case managed(configuration: URLSessionConfiguration, delegateQueue: OperationQueue)
        case injected(URLSession)
    }

    private let storage: SessionStorage
    private let securityConfig: NISSSL.SecurityConfig
    private let securityPipeline: NISSecurityPipeline
    private let logger: any NISSecurityLogging

    private lazy var session: URLSession = {
        switch storage {
        case .managed(let configuration, let delegateQueue):
            return URLSession(
                configuration: configuration,
                delegate: self,
                delegateQueue: delegateQueue
            )

        case .injected(let session):
            return session
        }
    }()

    // MARK: - Init

    /// Creates a secure URL session managed by NIS.
    ///
    /// - Parameters:
    ///   - configuration: Session configuration.
    ///   - qualityOfService: QoS used by the delegate queue.
    ///   - securityConfig: Optional security behavior for preflight and trust handling.
    ///   - logger: Optional security logger.
    public init(
        configuration: URLSessionConfiguration,
        qualityOfService: QualityOfService = .utility,
        securityConfig: NISSSL.SecurityConfig,
        logger: any NISSecurityLogging = .noOp
    ) {
        let delegateQueue = OperationQueue()
        delegateQueue.qualityOfService = qualityOfService

        self.storage = .managed(
            configuration: configuration,
            delegateQueue: delegateQueue
        )
        self.securityConfig = securityConfig
        self.logger = logger
        self.securityPipeline = NISSecurityPipeline(
            proxyValidator: NISSystemProxyValidator(),
            localCertificateValidator: NISLocalPinnedCertificatesValidator()
        )

        super.init()
    }

    /// Creates a session using an externally provided `URLSession`.
    ///
    /// This initializer is primarily intended for tests or custom transport mocking.
    ///
    /// Important:
    /// If the injected `URLSession` has its own delegate, authentication challenges are handled
    /// by that session, not by `NISSecureURLSession`. For that reason, this initializer defaults
    /// to no custom security configuration.
    public init(
        urlSession: URLSession,
        logger: any NISSecurityLogging = .noOp
    ) {
        self.storage = .injected(urlSession)
        self.securityConfig = .init(trustMode: .disabled)
        self.logger = logger
        self.securityPipeline = NISSecurityPipeline(
            proxyValidator: NISSystemProxyValidator(),
            localCertificateValidator: NISLocalPinnedCertificatesValidator()
        )

        super.init()
    }

    // MARK: - Public

    /// Executes an HTTP request.
    ///
    /// The method performs preflight validation before request execution:
    /// - optional proxy detection
    /// - local pinned certificate validation
    ///
    /// If pinning or system trust override is enabled, actual server trust evaluation
    /// happens later in the `URLSessionDelegate` challenge callback.
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try securityPipeline.validatePreflight(
            for: request,
            config: securityConfig,
            logger: logger
        )

        return try await session.data(for: request, delegate: nil)
    }
}

// MARK: - URLSessionDelegate

extension NISSecureURLSession: URLSessionDelegate {

    /// Performs server trust evaluation based on selected SecurityConfig mode.
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }

        let host = challenge.protectionSpace.host

        switch securityConfig.trustMode {
        case .disabled:
            return (.performDefaultHandling, nil)

        case .system:
            return performEvaluation(using: NISSystemTrustEvaluator(), trust: serverTrust, host: host)

        case .pinnedCertificates(let certificates, let validatesHost, let validatesChain):
            let evaluator = NISPinnedCertificatesTrustEvaluator(
                pinnedCertificates: certificates,
                validatesHost: validatesHost,
                validatesCertificateChain: validatesChain
            )
            return performEvaluation(using: evaluator, trust: serverTrust, host: host)
            
        case .publicKey(let pinnedHashes):
            let evaluator = NISPublicKeyTrustEvaluator(pinnedHashes: pinnedHashes)
            return performEvaluation(using: evaluator, trust: serverTrust, host: host)
        }
    }
    
    private func performEvaluation(
        using evaluator: any NISServerTrustEvaluating,
        trust: SecTrust,
        host: String
    ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        do {
            try evaluator.evaluate(trust, for: host, logger: logger)
            return (.useCredential, URLCredential(trust: trust))
        } catch {
            logger.log(.securityError(error, host: host))
            return (.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Security Pipeline

/// Preflight security pipeline executed before request dispatch.
private struct NISSecurityPipeline: Sendable {
    let proxyValidator: any NISProxyValidating
    let localCertificateValidator: any NISLocalCertificateValidating

    func validatePreflight(
        for request: URLRequest,
        config: NISSSL.SecurityConfig,
        logger: any NISSecurityLogging
    ) throws {
        logger.log(.preflightValidationStarted(url: request.url))
        
        if config.blocksProxies {
            try proxyValidator.validateNoProxy(for: request.url, logger: logger)
        }

        switch config.trustMode {
        case .disabled, .system, .publicKey:
            break

        case .pinnedCertificates(let certificates, _, _):
            try localCertificateValidator.validate(certificates: certificates, logger: logger)
        }
        
        logger.log(.preflightValidationPassed(url: request.url))
    }
}

// MARK: - Proxy Validation

protocol NISProxyValidating: Sendable {
    func validateNoProxy(for url: URL?, logger: any NISSecurityLogging) throws
}

/// Detects proxy usage through CFNetwork system proxy settings.
private struct NISSystemProxyValidator: NISProxyValidating {

    func validateNoProxy(for url: URL?, logger: any NISSecurityLogging) throws {
        guard isProxyEnabled(for: url) else { return }

        logger.log(.proxyDetected(url: url))
        throw NISSecurityError.proxyDetected
    }

    private func isProxyEnabled(for url: URL?) -> Bool {
        guard let url,
              let proxySettings = CFNetworkCopySystemProxySettings()?.takeUnretainedValue(),
              let proxies = CFNetworkCopyProxiesForURL(url as CFURL, proxySettings)
                .takeUnretainedValue() as? [[String: Any]]
        else {
            return false
        }

        return proxies.contains {
            ($0[kCFProxyTypeKey as String] as? String) != (kCFProxyTypeNone as String)
        }
    }
}

// MARK: - Local Certificate Validation

protocol NISLocalCertificateValidating: Sendable {
    func validate(certificates: [NISSSL.Certificate], logger: any NISSecurityLogging) throws
}

/// Validates local pinned certificates before request execution.
private struct NISLocalPinnedCertificatesValidator: NISLocalCertificateValidating {

    func validate(
        certificates: [NISSSL.Certificate],
        logger: any NISSecurityLogging
    ) throws {
        guard !certificates.isEmpty else { throw NISSecurityError.missingPinnedCertificates }

        for certificate in certificates {
            _ = try createSecCertificate(from: certificate)
        }

        logger.log(.localPinnedCertificatesValidated(count: certificates.count))
    }

    private func createSecCertificate(from certificate: NISSSL.Certificate) throws -> SecCertificate {
        guard let data = Data(base64Encoded: certificate.rawValue),
              let secCertificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw NISSecurityError.invalidLocalCertificate
        }
        return secCertificate
    }
}

// MARK: - Server Trust Evaluation

protocol NISServerTrustEvaluating: Sendable {
    func evaluate(
        _ serverTrust: SecTrust,
        for host: String,
        logger: any NISSecurityLogging
    ) throws
}

/// Trust evaluator that relies only on Apple's system trust.
private struct NISSystemTrustEvaluator: NISServerTrustEvaluating {

    func evaluate(
        _ serverTrust: SecTrust,
        for host: String,
        logger: any NISSecurityLogging
    ) throws {
        logger.log(.systemTrustEvaluationStarted(host: host))

        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            throw NISSecurityError.systemTrustEvaluationFailed(host: host)
        }

        logger.log(.systemTrustEvaluationSucceeded(host: host))
    }
}

/// Trust evaluator that relies on Subject Public Key Info (SPKI) pinning.
private struct NISPublicKeyTrustEvaluator: NISServerTrustEvaluating {
    let pinnedHashes: Set<String>

    func evaluate(_ serverTrust: SecTrust, for host: String, logger: any NISSecurityLogging) throws {
        logger.log(.pinningValidationStarted(host: host))
        
        let systemEvaluator = NISSystemTrustEvaluator()
        try systemEvaluator.evaluate(serverTrust, for: host, logger: logger)

        let serverHashes = serverTrust.certificateChain.compactMap { cert -> String? in
            guard let publicKey = SecCertificateCopyKey(cert),
                  let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
                return nil
            }
            return SHA256.hash(data: publicKeyData).map { String(format: "%02x", $0) }.joined()
        }

        guard !Set(serverHashes).isDisjoint(with: pinnedHashes) else {
            throw NISSecurityError.pinnedKeyMismatch
        }

        logger.log(.pinningValidationSucceeded(host: host))
    }
}

/// Trust evaluator that combines system trust with certificate pinning.
private struct NISPinnedCertificatesTrustEvaluator: NISServerTrustEvaluating {
    let pinnedCertificates: [NISSSL.Certificate]
    let validatesHost: Bool
    let validatesCertificateChain: Bool

    func evaluate(
        _ serverTrust: SecTrust,
        for host: String,
        logger: any NISSecurityLogging
    ) throws {
        logger.log(.pinningValidationStarted(host: host))

        let policy = validatesHost ? SecPolicyCreateSSL(true, host as CFString) : SecPolicyCreateBasicX509()
        SecTrustSetPolicies(serverTrust, policy)

        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            throw NISSecurityError.invalidServerTrustPolicy
        }

        let localCertificates = try pinnedCertificates.map { cert -> SecCertificate in
            guard let data = Data(base64Encoded: cert.rawValue),
                  let secCert = SecCertificateCreateWithData(nil, data as CFData) else {
                throw NISSecurityError.invalidLocalCertificate
            }
            return secCert
        }
        
        try validatePinnedMatch(serverTrust: serverTrust, localCertificates: localCertificates)
        logger.log(.pinningValidationSucceeded(host: host))
    }

    private func validatePinnedMatch(serverTrust: SecTrust, localCertificates: [SecCertificate]) throws {
        let pinnedData = Set(localCertificates.map { SecCertificateCopyData($0) as Data })

        if validatesCertificateChain {
            let serverChainData = Set(serverTrust.certificatesData)
            guard !serverChainData.isDisjoint(with: pinnedData) else {
                throw NISSecurityError.pinnedCertificateMismatch
            }
        } else {
            guard let leaf = serverTrust.leafCertificate,
                  pinnedData.contains(SecCertificateCopyData(leaf) as Data) else {
                throw NISSecurityError.pinnedCertificateMismatch
            }
        }
    }
}

// MARK: - SecTrust Helpers

private extension SecTrust {
    var certificateChain: [SecCertificate] {
        (SecTrustCopyCertificateChain(self) as? [SecCertificate]) ?? []
    }

    var leafCertificate: SecCertificate? {
        certificateChain.first
    }

    var certificatesData: [Data] {
        certificateChain.map { SecCertificateCopyData($0) as Data }
    }
}
