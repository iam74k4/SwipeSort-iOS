//
//  SortResultStore.swift
//  SwipeSort
//
//  SwiftData-based storage for sort results
//

import Foundation
import SwiftData
import os

@MainActor
@Observable
final class SortResultStore {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.swipesort", category: "SortResultStore")
    
    // MARK: - Model Container
    
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext? { modelContainer?.mainContext }
    
    // MARK: - Cached Counts
    
    private(set) var keepCount: Int = 0
    private(set) var deleteCount: Int = 0
    private(set) var favoriteCount: Int = 0
    private(set) var unsortedCount: Int = 0  // スキップ（未整理）の数
    
    // MARK: - Cache for sortedIDs
    
    private var _sortedIDsCache: Set<String>?
    
    // MARK: - Cache for category lookups
    
    private var categoryCache: [String: SortCategory] = [:]
    
    var totalSortedCount: Int {
        keepCount + deleteCount + favoriteCount + unsortedCount
    }
    
    // MARK: - Undo
    
    private(set) var canUndo: Bool = false
    
    // MARK: - Error State
    
    private(set) var initializationError: Error?
    private(set) var isUsingFallbackStorage: Bool = false
    private(set) var isCriticalError: Bool = false
    
    var isInitialized: Bool {
        initializationError == nil || isUsingFallbackStorage
    }
    
    var hasStorageError: Bool {
        initializationError != nil
    }
    
    // MARK: - Initialization
    
    init() {
        // Try to create persistent storage first
        do {
            let schema = Schema([SortRecord.self, UndoRecord.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            refreshCounts()
            refreshUndoState()
            logger.info("Persistent storage initialized successfully")
        } catch {
            // Primary storage failed, try in-memory fallback
            logger.error("Failed to create persistent storage: \(error.localizedDescription). Attempting in-memory fallback.")
            initializationError = error
            
            do {
                let schema = Schema([SortRecord.self, UndoRecord.self])
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfig]
                )
                isUsingFallbackStorage = true
                logger.warning("Using in-memory fallback storage. Data will not persist across app launches.")
                
                refreshCounts()
                refreshUndoState()
            } catch let fallbackError {
                // Even in-memory storage failed - this is a critical error
                logger.critical("Critical: Failed to create even in-memory storage: \(fallbackError.localizedDescription)")
                isCriticalError = true
                
                // Final attempt with minimal configuration (no crash on failure)
                let schema = Schema([SortRecord.self, UndoRecord.self])
                let minimalConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                
                // Try without crashing - if this fails, storage is disabled but app continues
                modelContainer = try? ModelContainer(for: schema, configurations: [minimalConfig])
                
                if modelContainer == nil {
                    // Absolute final attempt with default configuration
                    modelContainer = try? ModelContainer(for: schema)
                }
                
                if modelContainer != nil {
                isUsingFallbackStorage = true
                    logger.warning("Using emergency storage configuration.")
                } else {
                    logger.critical("Fatal: All storage initialization attempts failed. Storage functionality is disabled.")
                }
            }
        }
    }
    
    // MARK: - Query
    
    var sortedIDs: Set<String> {
        // Return cached value if available
        if let cached = _sortedIDsCache {
            return cached
        }
        
        // Fetch from database and cache
        guard let modelContext else {
            _sortedIDsCache = []
            return []
        }
        
        let descriptor = FetchDescriptor<SortRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        let ids = Set(records.map { $0.assetID })
        _sortedIDsCache = ids
        return ids
    }
    
    /// Invalidate sortedIDs cache (call after mutations)
    private func invalidateSortedIDsCache() {
        _sortedIDsCache = nil
    }
    
    var deleteIDs: [String] {
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.categoryRaw == "delete" },
            sortBy: [SortDescriptor(\.sortedAt, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map { $0.assetID }
    }
    
    var favoriteIDs: [String] {
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.categoryRaw == "favorite" },
            sortBy: [SortDescriptor(\.sortedAt, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map { $0.assetID }
    }
    
    var keepIDs: [String] {
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.categoryRaw == "keep" },
            sortBy: [SortDescriptor(\.sortedAt, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map { $0.assetID }
    }
    
    func category(for assetID: String) -> SortCategory? {
        // Check cache first
        if let cached = categoryCache[assetID] {
            return cached
        }
        
        // Fetch from database
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.assetID == assetID }
        )
        guard let record = try? modelContext.fetch(descriptor).first else {
            // Cache nil result to avoid repeated queries for non-existent records
            categoryCache[assetID] = nil
            return nil
        }
        
        // Use categoryRaw to ensure we get the actual stored value, not the transient property
        let category = SortCategory(rawValue: record.categoryRaw)
        categoryCache[assetID] = category
        return category
    }
    
    /// Invalidate category cache for a specific asset or all assets
    private func invalidateCategoryCache(for assetID: String? = nil) {
        if let assetID = assetID {
            categoryCache.removeValue(forKey: assetID)
        } else {
            categoryCache.removeAll()
        }
    }
    
    // MARK: - Mutations
    
    func addOrUpdate(assetID: String, category: SortCategory, previousCategory: SortCategory? = nil, recordUndo: Bool = true) {
        guard let modelContext else {
            logger.error("Cannot add/update: storage is unavailable")
            return
        }
        
        // Find existing record
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.assetID == assetID }
        )
        
        // Get the actual previous category from the database if not provided
        var actualPreviousCategory = previousCategory
        if let existing = try? modelContext.fetch(descriptor).first {
            // If previousCategory is not provided, get it from the existing record
            if actualPreviousCategory == nil {
                actualPreviousCategory = SortCategory(rawValue: existing.categoryRaw)
            }
            
            // Update both category and categoryRaw to ensure SwiftData tracks the change
            existing.category = category
            existing.categoryRaw = category.rawValue  // Explicitly update categoryRaw
            existing.sortedAt = Date()
        } else {
            let record = SortRecord(assetID: assetID, category: category)
            modelContext.insert(record)
        }
        
        // Add undo record (skip for delete actions as they cannot be undone)
        if recordUndo {
        let undoRecord = UndoRecord(
            assetID: assetID,
            previousCategory: actualPreviousCategory,
            newCategory: category
        )
        modelContext.insert(undoRecord)
        
        // Trim undo history (keep last 100)
        trimUndoHistory()
        }
        
        // Update caches
        invalidateSortedIDsCache()
        categoryCache[assetID] = category
        
        saveAndRefresh()
    }
    
    func remove(assetID: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.assetID == assetID }
        )
        
        if let record = try? modelContext.fetch(descriptor).first {
            modelContext.delete(record)
            // Invalidate caches
            invalidateSortedIDsCache()
            invalidateCategoryCache(for: assetID)
            saveAndRefresh()
        }
    }
    
    func remove(assetIDs: [String]) {
        guard let modelContext else { return }
        for id in assetIDs {
            let descriptor = FetchDescriptor<SortRecord>(
                predicate: #Predicate { $0.assetID == id }
            )
            if let record = try? modelContext.fetch(descriptor).first {
                modelContext.delete(record)
                // Invalidate category cache for each removed asset
                invalidateCategoryCache(for: id)
            }
        }
        // Invalidate sortedIDs cache once after all removals
        invalidateSortedIDsCache()
        saveAndRefresh()
    }
    
    // MARK: - Undo
    
    func undo() -> String? {
        guard let modelContext else { return nil }
        var descriptor = FetchDescriptor<UndoRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        guard let lastAction = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        let assetID = lastAction.assetID
        let previousCategory = lastAction.previousCategory
        let currentCategory = lastAction.newCategory  // The category we're undoing FROM
        
        // Get the current record to update counts correctly
        let sortDescriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.assetID == assetID }
        )
        let existingRecord = try? modelContext.fetch(sortDescriptor).first
        let actualCurrentCategory = existingRecord?.category ?? currentCategory
        
        // Remove the undo record first (before modifying sort records to avoid conflicts)
        modelContext.delete(lastAction)
        
        // Restore to previous category (or remove if was unsorted)
        if let previousCategory = previousCategory {
            // Restore to previous category
            // Pass actualCurrentCategory as previousCategory so counts are updated correctly
            addOrUpdate(assetID: assetID, category: previousCategory, previousCategory: actualCurrentCategory, recordUndo: false)
            // Note: addOrUpdate already invalidates caches
        } else {
            // Was unsorted, so remove the sort record
            // Delete the record directly (counts will be updated by refreshCounts)
            if let existingRecord = existingRecord {
                modelContext.delete(existingRecord)
                // Invalidate caches when removing record
                invalidateSortedIDsCache()
                invalidateCategoryCache(for: assetID)
            }
        }
        
        saveAndRefresh()
        
        return assetID
    }
    
    /// Create undo record only (without creating/updating SortRecord)
    /// Used when adding items to delete queue (before actual deletion)
    func createUndoRecord(assetID: String, previousCategory: SortCategory?) {
        guard let modelContext else { return }
        
        // Get current category (if exists)
        let currentCategory = category(for: assetID) ?? .unsorted
        
        // Create undo record (newCategory is current category since we're not changing it yet)
        let undoRecord = UndoRecord(
            assetID: assetID,
            previousCategory: previousCategory,
            newCategory: currentCategory
        )
        modelContext.insert(undoRecord)
        
        // Trim undo history (keep last 100)
        trimUndoHistory()
        
        saveAndRefresh()
    }
    
    /// Remove undo record for a specific asset (used when asset is actually deleted)
    func removeUndoRecord(for assetID: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<UndoRecord>(
            predicate: #Predicate { $0.assetID == assetID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        if let undoRecord = try? modelContext.fetch(descriptor).first {
            modelContext.delete(undoRecord)
            saveAndRefresh()
        }
    }
    
    private func trimUndoHistory() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<UndoRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        guard let allRecords = try? modelContext.fetch(descriptor),
              allRecords.count > 100 else {
            return
        }
        
        // Delete old records beyond 100
        for record in allRecords.dropFirst(100) {
            modelContext.delete(record)
        }
        // Note: saveAndRefresh() is called by the caller, so we don't save here
    }
    
    // MARK: - Reset
    
    func reset() {
        guard let modelContext else {
            logger.error("Cannot reset: storage is unavailable")
            return
        }
        // Delete all sort records
        do {
            try modelContext.delete(model: SortRecord.self)
            try modelContext.delete(model: UndoRecord.self)
            // Clear all caches
            invalidateSortedIDsCache()
            invalidateCategoryCache()
            saveAndRefresh()
            logger.info("All data reset")
        } catch {
            logger.error("Failed to reset: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private
    
    private func saveAndRefresh() {
        guard let modelContext else { return }
        do {
            // Process pending changes to ensure all updates are tracked
            modelContext.processPendingChanges()
            try modelContext.save()
            // Ensure changes are persisted before refreshing counts
            // This ensures that category changes are reflected in the counts
            refreshCounts()
            refreshUndoState()
        } catch {
            logger.error("Failed to save: \(error.localizedDescription)")
            // Even if save fails, try to refresh counts with current state
            refreshCounts()
            refreshUndoState()
        }
    }
    
    private func refreshCounts() {
        guard let modelContext else {
            keepCount = 0
            deleteCount = 0
            favoriteCount = 0
            unsortedCount = 0
            return
        }
        
        // Optimized: Single fetch instead of 4 separate fetches
        // Fetch all records once and group by category in memory
        do {
            let descriptor = FetchDescriptor<SortRecord>()
            let allRecords = try modelContext.fetch(descriptor)
            
            // Group by category and count
            var keep = 0
            var delete = 0
            var favorite = 0
            var unsorted = 0
            
            for record in allRecords {
                switch record.categoryRaw {
                case "keep":
                    keep += 1
                case "delete":
                    delete += 1
                case "favorite":
                    favorite += 1
                case "unsorted":
                    unsorted += 1
                default:
                    break
                }
            }
            
            keepCount = keep
            deleteCount = delete
            favoriteCount = favorite
            unsortedCount = unsorted
            
            logger.debug("Counts refreshed: keep=\(self.keepCount), delete=\(self.deleteCount), favorite=\(self.favoriteCount), unsorted=\(self.unsortedCount)")
        } catch {
            logger.error("Failed to refresh counts: \(error.localizedDescription)")
            // Fallback to individual fetchCount if single fetch fails
            keepCount = (try? modelContext.fetchCount(
                FetchDescriptor<SortRecord>(predicate: #Predicate { $0.categoryRaw == "keep" })
            )) ?? 0
            
            deleteCount = (try? modelContext.fetchCount(
                FetchDescriptor<SortRecord>(predicate: #Predicate { $0.categoryRaw == "delete" })
            )) ?? 0
            
            favoriteCount = (try? modelContext.fetchCount(
                FetchDescriptor<SortRecord>(predicate: #Predicate { $0.categoryRaw == "favorite" })
            )) ?? 0
            
            unsortedCount = (try? modelContext.fetchCount(
                FetchDescriptor<SortRecord>(predicate: #Predicate { $0.categoryRaw == "unsorted" })
            )) ?? 0
        }
    }
    
    private func refreshUndoState() {
        guard let modelContext else {
            canUndo = false
            return
        }
        let count = (try? modelContext.fetchCount(FetchDescriptor<UndoRecord>())) ?? 0
        canUndo = count > 0
    }
}

