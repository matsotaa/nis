//
//  CodingExtensionsTests.swift
//  NIS
//
//  Created by Andrew Matsota on 27.04.2026.
//

import XCTest

@testable import NIS

/// Unit tests for `Coding+Extensions`
final class CodingExtensionsTests: XCTestCase {
    
    // MARK: - Test Methods
    
    func testISO8601Date() {
        // GIVEN
        let date = Date(timeIntervalSince1970: 0)
        
        // THEN
        XCTAssertEqual(date.iso8601, "1970-01-01T00:00:00.000Z")
    }
    
    func testNISEncoder() throws {
        // GIVEN
        let date = Date(timeIntervalSince1970: 0)
        let payload = Model(
            date: date,
            z: "last",
            a: "first"
        )
        
        // WHEN
        let data = try JSONEncoder.nis.encode(payload)
        let json = String(decoding: data, as: UTF8.self)
        
        // THEN
        XCTAssertEqual(
            json,
            #"{"a":"first","date":"1970-01-01T00:00:00.000Z","z":"last"}"#
        )
    }
    
    func testNISShortDateEncoding() throws {
        // GIVEN
        let date = Date(timeIntervalSince1970: 100000)
        let payload = Model(
            date: date,
            z: "last",
            a: "first"
        )
        
        // WHEN
        let data = try JSONEncoder.nisShortDate.encode(payload)
        let json = String(decoding: data, as: UTF8.self)
        
        // THEN
        XCTAssertEqual(
            json,
            #"{"a":"first","date":"1970-01-02","z":"last"}"#
        )
    }
    
    func testNISDecoder() throws {
        // GIVEN
        func makeModel(with date: Any) throws -> SimpleModel {
            if let date = date as? String {
                return try JSONDecoder.nis.decode(from: try makeSimpeData(with: date))
            } else if let date = date as? Int {
                return try JSONDecoder.nis.decode(from: try makeSimpeData(with: date))
            }
            throw NSError(domain: "Unknown type to decode", code: 500)
        }

        // THEN
        XCTAssertEqual(
            try makeModel(with: "1970-01-01T00:00:00.000Z").date,
            Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(
            try makeModel(with: "1970-01-02T03:46:40Z").date,
            Date(timeIntervalSince1970: 100000)
        )
        XCTAssertEqual(
            try makeModel(with: "1970-01-01T03:46:40.123Z").date,
            Date(timeIntervalSince1970: 13600.123)
        )
        XCTAssertEqual(
            try makeModel(with: "1970-01-02").date,
            Date(timeIntervalSince1970: 75600)
        )
        XCTAssertEqual(
            try makeModel(with: "1000000").date,
            Date(timeIntervalSince1970: 1000000)
        )
        XCTAssertEqual(
            try makeModel(with: 100000).date,
            Date(timeIntervalSince1970: 100000)
        )
        
        XCTAssertThrowsError(try makeModel(with: "currepted date"))
    }
}

// MARK: - Private Helpers

private extension CodingExtensionsTests {
    struct Model: Codable {
        let date: Date
        let z: String
        let a: String
    }
    
    struct SimpleModel: Decodable {
        let date: Date
    }
    
    func makeSimpeData(with stringDate: String) throws -> Data {
        try self.makeData(
            json:
"""
{"date":"\(stringDate)"}
"""
        )
    }
    
    func makeSimpeData(with timeInterval: Int) throws -> Data {
        try self.makeData(
            json:
"""
{"date":\(timeInterval)}
"""
        )
    }
}
