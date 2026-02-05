//
//  DateExtensions.swift
//  SwipeSort
//
//  Date extension for relative time formatting
//

import Foundation

extension Date {
    /// Shared formatter for relative date strings
    /// Using a static formatter is more efficient than creating one per call
    /// Note: nonisolated(unsafe) is used because RelativeDateTimeFormatter is not Sendable,
    /// but the formatter is thread-safe for read operations
    nonisolated(unsafe) private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    /// Returns a relative time string (e.g., "2 years ago", "3日前") using system formatter.
    /// Uses RelativeDateTimeFormatter which handles:
    /// - Proper plural forms for all languages
    /// - System-consistent display
    /// - Automatic localization
    var relativeString: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: Date())
    }
}
