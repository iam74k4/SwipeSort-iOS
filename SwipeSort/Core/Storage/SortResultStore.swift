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
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<SortRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return Set(records.map { $0.assetID })
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
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.assetID == assetID }
        )
        guard let record = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        return record.category
    }
    
    // MARK: - Mutations
    
    func addOrUpdate(assetID: String, category: SortCategory, previousCategory: SortCategory? = nil) {
        guard let modelContext else {
            logger.error("Cannot add/update: storage is unavailable")
            return
        }
        
        // Find existing record
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.assetID == assetID }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.category = category
            existing.sortedAt = Date()
        } else {
            let record = SortRecord(assetID: assetID, category: category)
            modelContext.insert(record)
        }
        
        // Add undo record
        let undoRecord = UndoRecord(
            assetID: assetID,
            previousCategory: previousCategory,
            newCategory: category
        )
        modelContext.insert(undoRecord)
        
        // Trim undo history (keep last 100)
        trimUndoHistory()
        
        saveAndRefresh()
    }
    
    func remove(assetID: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.assetID == assetID }
        )
        
        if let record = try? modelContext.fetch(descriptor).first {
            modelContext.delete(record)
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
            }
        }
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
        
        // Remove the sort record
        remove(assetID: assetID)
        
        // Remove the undo record
        modelContext.delete(lastAction)
        
        saveAndRefresh()
        
        return assetID
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
            try modelContext.save()
            refreshCounts()
            refreshUndoState()
        } catch {
            logger.error("Failed to save: \(error.localizedDescription)")
        }
    }
    
    private func refreshCounts() {
        guard let modelContext else {
            keepCount = 0
            deleteCount = 0
            favoriteCount = 0
            return
        }
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
    
    private func refreshUndoState() {
        guard let modelContext else {
            canUndo = false
            return
        }
        let count = (try? modelContext.fetchCount(FetchDescriptor<UndoRecord>())) ?? 0
        canUndo = count > 0
    }
}

