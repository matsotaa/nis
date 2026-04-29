//
//  XCTest+Extensions.swift
//  NIS
//
//  Created by Andrew Matsota on 27.04.2026.
//

import XCTest

public extension XCTestCase {
    
    func makeData(json: String) throws -> Data {
        guard let data = json.data(using: .utf8) else { throw NSError(domain: "Invalid data", code: 500) }
        return data
    }
}
