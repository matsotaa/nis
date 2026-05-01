//
//  Result+Extensions.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

public extension Result {
    
    /// Unwrapped `value` of result of request execution.
    var value: Success? {
        guard case let .success(value) = self else { return nil }
        return value
    }
    
    /// Unwrapped `error` of result of request execution.
    var error: Failure? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
