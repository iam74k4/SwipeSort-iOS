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
        case .unsorted: return "未整理"
        case .keep: return "Keep"
        case .delete: return "削除候補"
        case .favorite: return "お気に入り"
        }
    }
    
    var iconName: String {
        switch self {
        case .unsorted: return "questionmark.circle"
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
    case none
    
    var category: SortCategory {
        switch self {
        case .left: return .delete
        case .right: return .keep
        case .none: return .unsorted
        }
    }
}
