//
//  ReviewState.swift
//  SwipeSort
//
//  State for the review feature
//

import Foundation

enum ReviewSegment: Int, CaseIterable {
    case delete = 0
    case favorite = 1
    
    var title: String {
        switch self {
        case .delete: return "削除候補"
        case .favorite: return "お気に入り"
        }
    }
    
    var icon: String {
        switch self {
        case .delete: return "trash"
        case .favorite: return "heart.fill"
        }
    }
}

@Observable
final class ReviewState {
    // MARK: - Segment
    
    var selectedSegment: ReviewSegment = .delete
    
    // MARK: - Items
    
    var deleteItems: [PhotoAsset] = []
    var favoriteItems: [PhotoAsset] = []
    var selectedIDs: Set<String> = []
    
    var currentItems: [PhotoAsset] {
        switch selectedSegment {
        case .delete: return deleteItems
        case .favorite: return favoriteItems
        }
    }
    
    // MARK: - UI State
    
    var isProcessing: Bool = false
    var showDeleteConfirmation: Bool = false
    var showDeleteAll: Bool = false
    var showRemoveFavoriteConfirmation: Bool = false
    var showSuccessMessage: Bool = false
    var successMessage: String = ""
    var errorMessage: String?
    
    // MARK: - Computed
    
    var selectedCount: Int {
        selectedIDs.count
    }
    
    var hasSelection: Bool {
        !selectedIDs.isEmpty
    }
    
    var allSelected: Bool {
        selectedIDs.count == currentItems.count && !currentItems.isEmpty
    }
    
    // MARK: - Methods
    
    func toggleSelection(for id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
    
    func selectAll() {
        selectedIDs = Set(currentItems.map { $0.id })
    }
    
    func deselectAll() {
        selectedIDs.removeAll()
    }
    
    func isSelected(_ id: String) -> Bool {
        selectedIDs.contains(id)
    }
    
    func clearSelection() {
        selectedIDs.removeAll()
    }
}
