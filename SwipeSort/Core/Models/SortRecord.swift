//
//  SortRecord.swift
//  SwipeSort
//
//  SwiftData model for sort records
//

import Foundation
import SwiftData

@Model
final class SortRecord {
    /// Photo asset identifier
    @Attribute(.unique) var assetID: String
    
    /// Sorting category
    var categoryRaw: String
    
    /// When this record was created/updated
    var sortedAt: Date
    
    var category: SortCategory {
        get { SortCategory(rawValue: categoryRaw) ?? .unsorted }
        set { categoryRaw = newValue.rawValue }
    }
    
    init(assetID: String, category: SortCategory) {
        self.assetID = assetID
        self.categoryRaw = category.rawValue
        self.sortedAt = Date()
    }
}

@Model
final class UndoRecord {
    /// Unique identifier
    var id: UUID
    
    /// Photo asset identifier
    var assetID: String
    
    /// Previous category (nil if was unsorted)
    var previousCategoryRaw: String?
    
    /// New category
    var newCategoryRaw: String
    
    /// When this action occurred
    var timestamp: Date
    
    var previousCategory: SortCategory? {
        get { previousCategoryRaw.flatMap { SortCategory(rawValue: $0) } }
        set { previousCategoryRaw = newValue?.rawValue }
    }
    
    var newCategory: SortCategory {
        get { SortCategory(rawValue: newCategoryRaw) ?? .unsorted }
        set { newCategoryRaw = newValue.rawValue }
    }
    
    init(assetID: String, previousCategory: SortCategory?, newCategory: SortCategory) {
        self.id = UUID()
        self.assetID = assetID
        self.previousCategoryRaw = previousCategory?.rawValue
        self.newCategoryRaw = newCategory.rawValue
        self.timestamp = Date()
    }
}
