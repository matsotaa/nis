//
//  NISSSL.swift
//  NIS
//
//  Created by Andrew Matsota on 21.04.2026.
//

/// Namespace for SSL / TLS models used by NIS networking security.
public enum NISSSL {

    /// A pinned X.509 certificate represented as a Base64-encoded DER string.
    ///
    /// Expected preparation flow:
    /// 1. Export certificate in DER format.
    /// 2. Base64-encode the DER data.
    /// 3. Store the resulting string in code or configuration.
    public struct Certificate: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    /// Defines how server trust should be handled.
    public enum TrustMode: Sendable {
        /// Disables custom trust handling.
        ///
        /// Requests rely on default `URLSession` trust behavior.
        case disabled

        /// Uses Apple's system trust validation only.
        ///
        /// This mode does not perform certificate pinning.
        case system

        /// Uses certificate pinning in addition to system trust validation.
        ///
        /// - Parameters:
        ///   - certificates: Local pinned certificates in Base64 DER form.
        ///   - validatesHost: Whether hostname should be part of trust evaluation.
        ///   - validatesCertificateChain: If `true`, any certificate from the server trust chain
        ///     may match one of the pinned certificates. If `false`, only the leaf certificate
        ///     is matched against the pinned set.
        case pinnedCertificates(
            certificates: [Certificate],
            validatesHost: Bool = true,
            validatesCertificateChain: Bool = true
        )
        
        /// Uses Public Key pinning (HPKP style) in addition to system trust validation.
        /// This is generally more robust than certificate pinning as keys change less frequently.
        /// - Parameters:
        ///   - hashes: A set of SHA-256 hashes of the Subject Public Key Info (SPKI).
        case publicKey(hashes: Set<String>)
    }

    /// Security configuration applied by `NISSecureURLSession`.
    public struct SecurityConfig: Sendable {
        public let trustMode: TrustMode
        public let blocksProxies: Bool

        public init(
            trustMode: TrustMode,
            blocksProxies: Bool = false
        ) {
            self.trustMode = trustMode
            self.blocksProxies = blocksProxies
        }
    }
}

