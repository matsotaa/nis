//
//  NISSecurityLogging.swift
//  NIS
//
//  Created by Andrew Matsota on 21.04.2026.
//

/// Lightweight hook for SDK-level observability.
public protocol NISSecurityLogging: Sendable {
    func log(_ event: NISSecurityEvent)
}
