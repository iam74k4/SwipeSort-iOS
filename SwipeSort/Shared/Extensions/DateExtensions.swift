//
//  DateExtensions.swift
//  SwipeSort
//
//  Date extension for relative time formatting
//

import Foundation

extension Date {
    /// Returns a relative time string (e.g., "2時間前", "3日前", "1週間前")
    var relativeString: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)
        
        if let year = components.year, year > 0 {
            return String(format: NSLocalizedString("%d年前", comment: "Years ago"), year)
        } else if let month = components.month, month > 0 {
            return String(format: NSLocalizedString("%dヶ月前", comment: "Months ago"), month)
        } else if let day = components.day, day > 0 {
            return String(format: NSLocalizedString("%d日前", comment: "Days ago"), day)
        } else if let hour = components.hour, hour > 0 {
            return String(format: NSLocalizedString("%d時間前", comment: "Hours ago"), hour)
        } else if let minute = components.minute, minute > 0 {
            return String(format: NSLocalizedString("%d分前", comment: "Minutes ago"), minute)
        } else {
            return NSLocalizedString("たった今", comment: "Just now")
        }
    }
}
