//
//  SortCategory.swift
//  SwipeSort
//
//  Sorting categories enum
//

import SwiftUI

/// Represents the sorting category for a media item
enum SortCategory: String, Codable, CaseIterable, Sendable {
    case unsorted
    case keep
    case delete
    case favorite
    
    var displayName: String {
        switch self {
        case .unsorted: return NSLocalizedString("Unsorted", comment: "Unsorted category")
        case .keep: return NSLocalizedString("Keep", comment: "Keep category")
        case .delete: return NSLocalizedString("Deleted", comment: "Deleted category")
        case .favorite: return NSLocalizedString("Favorites", comment: "Favorites category")
        }
    }
    
    var iconName: String {
        switch self {
        case .unsorted: return "arrow.up.circle.fill"  // Skip uses arrow.up
        case .keep: return "checkmark.circle.fill"
        case .delete: return "trash.circle.fill"
        case .favorite: return "heart.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .unsorted: return .gray
        case .keep: return .keepColor
        case .delete: return .deleteColor
        case .favorite: return .favoriteColor
        }
    }
}

/// Swipe direction enum
enum SwipeDirection: String, Codable, Sendable {
    case left   // Delete
    case right  // Keep
    case up     // Skip (decide later)
    case none
    
    var category: SortCategory {
        switch self {
        case .left: return .delete
        case .right: return .keep
        case .up: return .unsorted  // Skip keeps it unsorted
        case .none: return .unsorted
        }
    }
}
