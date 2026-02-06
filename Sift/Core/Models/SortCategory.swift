//
//  SortCategory.swift
//  Sift
//
//  Sorting categories enum
//

import Foundation

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
        case .unsorted: return "arrow.up.circle.fill"  // unsorted (legacy Skip icon)
        case .keep: return "checkmark.circle.fill"
        case .delete: return "trash.circle.fill"
        case .favorite: return "heart.circle.fill"
        }
    }
}

/// Swipe direction enum
enum SwipeDirection: String, Codable, Sendable {
    case left   // Delete
    case right  // Keep
    case none
    
    var category: SortCategory {
        switch self {
        case .left: return .delete
        case .right: return .keep
        case .none: return .unsorted
        }
    }
}
