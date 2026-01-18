//
//  SortRecord.swift
//  SwipeSort
//
//  SwiftData models for storing sort results
//

import Foundation
import SwiftData

/// SwiftData model for storing sort category assignments
@Model
final class SortRecord {
    @Attribute(.unique) var assetID: String
    var categoryRaw: String
    var sortedAt: Date
    
    init(assetID: String, category: SortCategory) {
        self.assetID = assetID
        self.categoryRaw = category.rawValue
        self.sortedAt = Date()
    }
    
    var category: SortCategory {
        get {
            SortCategory(rawValue: categoryRaw) ?? .unsorted
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }
}

/// SwiftData model for storing undo history
@Model
final class UndoRecord {
    var assetID: String
    var previousCategoryRaw: String?
    var newCategoryRaw: String
    var timestamp: Date
    
    init(assetID: String, previousCategory: SortCategory?, newCategory: SortCategory) {
        self.assetID = assetID
        self.previousCategoryRaw = previousCategory?.rawValue
        self.newCategoryRaw = newCategory.rawValue
        self.timestamp = Date()
    }
    
    var previousCategory: SortCategory? {
        guard let raw = previousCategoryRaw else { return nil }
        return SortCategory(rawValue: raw)
    }
    
    var newCategory: SortCategory {
        get {
            SortCategory(rawValue: newCategoryRaw) ?? .unsorted
        }
        set {
            newCategoryRaw = newValue.rawValue
        }
    }
}
