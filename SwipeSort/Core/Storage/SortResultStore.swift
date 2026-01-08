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
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext { modelContainer.mainContext }
    
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
    
    var isInitialized: Bool {
        initializationError == nil
    }
    
    // MARK: - Initialization
    
    init() {
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
        } catch {
            // Create in-memory fallback container
            logger.error("Failed to create persistent storage: \(error.localizedDescription). Using in-memory storage.")
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
            } catch {
                // This should never happen with in-memory storage
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
    }
    
    // MARK: - Query
    
    var sortedIDs: Set<String> {
        let descriptor = FetchDescriptor<SortRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return Set(records.map { $0.assetID })
    }
    
    var deleteIDs: [String] {
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.categoryRaw == "delete" },
            sortBy: [SortDescriptor(\.sortedAt, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map { $0.assetID }
    }
    
    var favoriteIDs: [String] {
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.categoryRaw == "favorite" },
            sortBy: [SortDescriptor(\.sortedAt, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map { $0.assetID }
    }
    
    var keepIDs: [String] {
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.categoryRaw == "keep" },
            sortBy: [SortDescriptor(\.sortedAt, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map { $0.assetID }
    }
    
    func category(for assetID: String) -> SortCategory? {
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
        let descriptor = FetchDescriptor<SortRecord>(
            predicate: #Predicate { $0.assetID == assetID }
        )
        
        if let record = try? modelContext.fetch(descriptor).first {
            modelContext.delete(record)
            saveAndRefresh()
        }
    }
    
    func remove(assetIDs: [String]) {
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
        do {
            try modelContext.save()
            refreshCounts()
            refreshUndoState()
        } catch {
            logger.error("Failed to save: \(error.localizedDescription)")
        }
    }
    
    private func refreshCounts() {
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
        let count = (try? modelContext.fetchCount(FetchDescriptor<UndoRecord>())) ?? 0
        canUndo = count > 0
    }
}

