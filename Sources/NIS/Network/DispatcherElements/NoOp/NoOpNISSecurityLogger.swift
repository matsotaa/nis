//
//  NoOpNISSecurityLogger.swift
//  NIS
//
//  Created by Andrew Matsota on 21.04.2026.
//

/// Default no-op logger.
public enum NoOpNISSecurityLogger: NISSecurityLogging {
    
    case shared

    public func log(_ event: NISSecurityEvent) {
        // Intentionally left empty
    }
}

public extension NISSecurityLogging where Self == NoOpNISSecurityLogger {

    /// Provides a no-op security logger
    static var noOp: NoOpNISSecurityLogger { .shared }
}
