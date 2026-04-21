//
//  DateFormatters.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

import Foundation

public extension Date {
    
    func stringWithFormat(_ format: String) -> String {
        DateFormatters.shared.dateFormatter(with: format).string(from: self)
    }

    func localizedStringWithFormat(_ template: String) -> String {
        DateFormatters.shared.localizedDateFormatter(with: template).string(from: self)
    }
}

public extension String {
    
    func dateWithFormat(_ format: String) -> Date? {
        DateFormatters.shared.dateFormatter(with: format).date(from: self)
    }
}

// MARK: - Date Formatters

private class DateFormatters: @unchecked Sendable {
    static let shared = DateFormatters()
    
    private let iso8601Formatter = ISO8601DateFormatter()

    private var formatters: [String: DateFormatter] = [:]
    private var localizedFormatters: [String: DateFormatter] = [:]
    
    private init() { }
    
    func dateFormatter(with format: String) -> DateFormatter {
        if let formatter = formatters[format] { return formatter }

        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatters[format] = formatter
        return formatter
    }
    
    func localizedDateFormatter(with format: String) -> DateFormatter {
        if let formatter = localizedFormatters[format] { return formatter }
        
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(format)
        localizedFormatters[format] = formatter
        return formatter
    }
}
