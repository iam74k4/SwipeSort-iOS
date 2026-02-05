//
//  SortResultStore.swift
//  SwipeSort
//
//  SwiftData-based storage for sort results
//

import Foundation
import SwiftData
import os

// MARK: - Constants

private enum StoreConstants {
    /// Maximum number of undo records to keep in history
    static let maxUndoHistoryCount = 100
}

@MainActor
@Observable
final class SortResultStore {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.swipesort", category: "SortResultStore")
    
    // MARK: - Model Container
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext? { modelContainer?.mainContext }
    
    // MARK: - Cached Counts
    
    private(set) var keepCount: Int = 0
    private(set) var deleteCount: Int = 0
    private(set) var favoriteCount: Int = 0
    
    // MARK: - Cache for sortedIDs
    
    private var _sortedIDsCache: Set<String>?
    
    // MARK: - Cache for category lookups
    
    private var categoryCache: [String: SortCategory] = [:]
    
    var totalSortedCount: Int {
        keepCount + deleteCount + favoriteCount
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
        setupStorage()
    }
    
    // MARK: - Storage Setup
    
    /// Main storage setup orchestrator with fallback chain
    private func setupStorage() {
        // Try persistent storage first
        if setupPersistentStorage() {
            return
        }
        
        // Persistent failed, try in-memory fallback
        if setupInMemoryFallback() {
            return
        }
        
        // Even in-memory failed, try emergency storage
        setupEmergencyStorage()
    }
    
    /// Attempts to setup persistent (on-disk) storage
    /// - Returns: true if successful
    private func setupPersistentStorage() -> Bool {
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
            
            finalizeSetup()
            logger.info("Persistent storage initialized successfully")
            return true
        } catch {
            logger.error("Failed to create persistent storage: \(error.localizedDescription). Attempting in-memory fallback.")
            initializationError = error
            return false
        }
    }
    
    /// Attempts to setup in-memory fallback storage
    /// - Returns: true if successful
    private func setupInMemoryFallback() -> Bool {
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
            
            finalizeSetup()
            logger.warning("Using in-memory fallback storage. Data will not persist across app launches.")
            return true
        } catch {
            logger.critical("Critical: Failed to create even in-memory storage: \(error.localizedDescription)")
            isCriticalError = true
            return false
        }
    }
    
    /// Last-resort emergency storage setup (non-throwing)
    private func setupEmergencyStorage() {
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
    
    /// Common setup finalization after container is created
    private func finalizeSetup() {
        refreshCounts()
        refreshUndoState()
        cleanupUnsortedData()
    }
    
    // MARK: - Query
    
    /// Returns a set of all asset IDs that have been sorted into any category.
    ///
    /// This property returns a cached set of sorted asset IDs for efficient
    /// filtering. The cache is automatically invalidated when sort records are
    /// added, updated, or removed.
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
    
    /// Returns the sort category for the specified asset ID.
    ///
    /// This method uses a cache to avoid repeated database queries for the same
    /// asset. If the asset has not been sorted, returns `nil`.
    ///
    /// - Parameter assetID: The asset identifier to look up
    /// - Returns: The `SortCategory` for the asset, or `nil` if not sorted
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
    
    /// Adds or updates a sort record for the specified asset.
    ///
    /// This method creates a new sort record if one doesn't exist, or updates
    /// an existing record with the new category. It also creates an undo record
    /// by default to allow reverting the action.
    ///
    /// - Parameters:
    ///   - assetID: The asset identifier to sort
    ///   - category: The category to assign to the asset
    ///   - previousCategory: The previous category (if known). If `nil`, it will
    ///     be retrieved from the existing record or set to `nil` for new records
    ///   - recordUndo: If `true`, creates an undo record. Set to `false` when
    ///     performing undo operations to avoid infinite undo chains
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
            trimUndoHistory()
        }
        
        // Update caches
        invalidateSortedIDsCache()
        categoryCache[assetID] = category
        
        saveAndRefresh()
    }
    
    /// Removes the sort record for the specified asset.
    ///
    /// This method removes the asset from sorted categories, effectively marking
    /// it as unsorted. The asset can be sorted again later.
    ///
    /// - Parameter assetID: The asset identifier to remove from sorted records
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
    
    /// Removes sort records for multiple assets.
    ///
    /// This method is more efficient than calling `remove(assetID:)` multiple times
    /// as it performs a single database save operation after all removals.
    ///
    /// - Parameter assetIDs: An array of asset identifiers to remove from sorted records
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
    
    /// Reverts the last sorting action.
    ///
    /// This method restores the previous category for the most recently sorted asset,
    /// or removes the sort record if the asset was previously unsorted. The undo
    /// history is limited to the last 100 actions.
    ///
    /// - Returns: The asset ID that was undone, or `nil` if there are no actions to undo
    /// - Note: This method does not create a new undo record to avoid infinite undo chains
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
    
    /// Creates an undo record without modifying the sort record.
    ///
    /// This method is used when adding items to the delete queue, before the actual
    /// deletion occurs. It allows the user to undo the action of adding an item
    /// to the delete queue.
    ///
    /// - Parameters:
    ///   - assetID: The asset identifier
    ///   - previousCategory: The previous category before adding to delete queue
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
    
    /// Removes the undo record for a specific asset.
    ///
    /// This method is called when an asset is actually deleted from the photo library,
    /// as deleted assets cannot be undone.
    ///
    /// - Parameter assetID: The asset identifier whose undo record should be removed
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
              allRecords.count > StoreConstants.maxUndoHistoryCount else {
            return
        }
        
        // Delete old records beyond limit
        for record in allRecords.dropFirst(StoreConstants.maxUndoHistoryCount) {
            modelContext.delete(record)
        }
        // Note: saveAndRefresh() is called by the caller, so we don't save here
    }
    
    // MARK: - Reset
    
    /// Resets all sorting data, removing all sort records and undo history.
    ///
    /// This method permanently deletes all sort records and undo records from the
    /// database. This action cannot be undone.
    ///
    /// - Warning: This operation is destructive and cannot be reversed
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
            
            for record in allRecords {
                switch record.categoryRaw {
                case "keep":
                    keep += 1
                case "delete":
                    delete += 1
                case "favorite":
                    favorite += 1
                case "unsorted":
                    // Skip unsorted records (they will be cleaned up)
                    break
                default:
                    break
                }
            }
            
            keepCount = keep
            deleteCount = delete
            favoriteCount = favorite
            
            logger.debug("Counts refreshed: keep=\(self.keepCount), delete=\(self.deleteCount), favorite=\(self.favoriteCount)")
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
    
    /// Cleans up existing .unsorted data by removing all records with .unsorted category.
    ///
    /// This method is called on app startup to remove any existing .unsorted records
    /// that were created before the Skip feature was removed.
    private func cleanupUnsortedData() {
        guard let modelContext else { return }
        
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.categoryRaw == "unsorted" }
        )
        
        do {
            let unsortedRecords = try modelContext.fetch(descriptor)
            let assetIDs = unsortedRecords.map { $0.assetID }
            
            if !assetIDs.isEmpty {
                remove(assetIDs: assetIDs)
                logger.info("Cleaned up \(assetIDs.count) unsorted records")
            }
        } catch {
            logger.error("Failed to cleanup unsorted data: \(error.localizedDescription)")
        }
    }
}

