//
//  SortingState.swift
//  Sift
//
//  State for the sorting feature
//

import SwiftUI
@preconcurrency import Photos

/// Filter type for sorting view
enum MediaFilter: String, CaseIterable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"
    case livePhotos = "Live Photos"
    case screenshots = "Screenshots"
    
    var icon: String {
        switch self {
        case .all: return "square.stack"
        case .photos: return "photo"
        case .videos: return "video"
        case .livePhotos: return "livephoto"
        case .screenshots: return "camera.viewfinder"
        }
    }
    
    var localizedName: String {
        switch self {
        case .all: return NSLocalizedString("All", comment: "All media filter")
        case .photos: return NSLocalizedString("Photos", comment: "Photos filter")
        case .videos: return NSLocalizedString("Videos", comment: "Videos filter")
        case .livePhotos: return NSLocalizedString("Live Photos", comment: "Live Photos filter")
        case .screenshots: return NSLocalizedString("Screenshots", comment: "Screenshots filter")
        }
    }
}

/// Sort order for assets
enum SortOrder: String, CaseIterable {
    case newestFirst = "newest"
    case oldestFirst = "oldest"
    
    var icon: String {
        switch self {
        case .newestFirst: return "arrow.down"
        case .oldestFirst: return "arrow.up"
        }
    }
    
    var localizedName: String {
        switch self {
        case .newestFirst: return NSLocalizedString("Newest First", comment: "Sort by newest first")
        case .oldestFirst: return NSLocalizedString("Oldest First", comment: "Sort by oldest first")
        }
    }
    
    mutating func toggle() {
        self = self == .newestFirst ? .oldestFirst : .newestFirst
    }
}

@Observable
final class SortingState {
    // MARK: - Assets
    
    var allAssets: [PhotoAsset] = []          // All assets (sorted + unsorted)
    var allUnsortedAssets: [PhotoAsset] = []  // All unsorted assets (before filter)
    var unsortedAssets: [PhotoAsset] = []     // Filtered assets currently shown
    var currentIndex: Int = 0
    var currentAsset: PhotoAsset?
    
    var totalCount: Int = 0
    
    var isComplete: Bool = false
    
    // MARK: - Filter
    
    var currentFilter: MediaFilter = .all
    var selectedCategoryFilter: SortCategory? = nil  // Category filter (selected via stat pill)
    var sortOrder: SortOrder = .newestFirst
    var selectedDate: Date? = nil  // Single date filter
    var dateRangeStart: Date? = nil  // Date range filter start
    var dateRangeEnd: Date? = nil  // Date range filter end
    
    var hasDateFilter: Bool {
        selectedDate != nil || (dateRangeStart != nil && dateRangeEnd != nil)
    }
    
    // MARK: - Image Loading
    
    var currentImage: UIImage?
    var nextImage: UIImage?
    var isLoadingImage: Bool = false
    
    // MARK: - Live Photo
    
    var currentLivePhoto: PHLivePhoto?
    var isPlayingLivePhoto: Bool = false
    var isLongPressing: Bool = false

    // MARK: - Video

    var isPlayingVideo: Bool = false
    var isVideoPaused: Bool = false
    var videoCurrentTime: Double = 0
    var videoDuration: Double = 0
    var isSeeking: Bool = false
    
    // MARK: - Burst Photos
    
    var showingBurstSelector: Bool = false
    var burstAssets: [PhotoAsset] = []
    var currentBurstCount: Int?
    
    // MARK: - Delete Queue (batch delete to reduce iOS confirmation dialogs)
    
    var deleteQueue: [PhotoAsset] = []
    
    // MARK: - Swipe State
    
    var offset: CGSize = .zero
    var swipeDirection: SwipeDirection = .none
    var isAnimatingOut: Bool = false
    var imageOpacity: Double = 1.0
    
    // MARK: - Undo State
    
    var isUndoing: Bool = false  // Flag to prevent rapid undo taps
    
    // MARK: - Double Tap (Favorite)
    
    var showHeartAnimation: Bool = false
    
    // MARK: - Computed
    
    var swipeProgress: Double {
        let horizontal = abs(offset.width) / SwipeThreshold.horizontal
        let vertical = abs(offset.height) / SwipeThreshold.vertical
        return min(max(horizontal, vertical), 1.0)
    }
    
    var remainingCount: Int {
        unsortedAssets.count
    }
    
    // MARK: - Methods
    
    /// Updates the current asset based on the current index.
    ///
    /// This method sets `currentAsset` to the asset at `currentIndex` in the
    /// `unsortedAssets` array, or `nil` if the array is empty. It also resets
    /// Live Photo and video playback state when the asset changes.
    func updateCurrentAsset() {
        if unsortedAssets.isEmpty {
            currentAsset = nil
            currentBurstCount = nil
        } else if currentIndex < unsortedAssets.count {
            currentAsset = unsortedAssets[currentIndex]
        } else {
            currentIndex = 0
            currentAsset = unsortedAssets.first
        }
        
        // Reset media state when changing asset
        currentLivePhoto = nil
        isPlayingLivePhoto = false
        resetVideoState()
    }
    
    /// Resets all video-related state to initial values.
    func resetVideoState() {
        isPlayingVideo = false
        isVideoPaused = false
        videoCurrentTime = 0
        videoDuration = 0
        isSeeking = false
    }
    
    /// Resets all swipe and animation state to initial values.
    ///
    /// This method clears the swipe offset, direction, animation flags, and
    /// media playback state. It's typically called when starting a new swipe
    /// or when canceling an in-progress swipe.
    func reset() {
        offset = .zero
        swipeDirection = .none
        isAnimatingOut = false
        imageOpacity = 1.0
        isPlayingLivePhoto = false
        isLongPressing = false
        showHeartAnimation = false
        
        // Reset video state
        resetVideoState()
        
        // Reset image loading state
        currentImage = nil
        nextImage = nil
        isLoadingImage = false
        currentBurstCount = nil
    }
    
    /// Resets the burst photo selector state.
    ///
    /// This method hides the burst selector overlay and clears the burst assets list.
    func resetBurstSelector() {
        showingBurstSelector = false
        burstAssets = []
    }
    
    /// Applies a media type filter to the assets.
    ///
    /// This method filters assets by media type (photos, videos, Live Photos, screenshots, or all).
    /// If a `sortStore` is provided, it also applies category filtering.
    ///
    /// - Parameters:
    ///   - filter: The media type filter to apply
    ///   - sortStore: Optional sort store for category filtering
    @MainActor
    func applyFilter(_ filter: MediaFilter, sortStore: SortResultStore? = nil) {
        currentFilter = filter
        if let sortStore = sortStore {
            applyFiltersWithCategory(sortStore: sortStore)
        } else {
            applyFilters()
        }
    }
    
    /// Apply media filter to assets
    private func applyMediaFilter(to assets: [PhotoAsset]) -> [PhotoAsset] {
        switch currentFilter {
        case .all:
            return assets  // No filter
        case .photos:
            return assets.filter { $0.isImage && !$0.isLivePhoto }
        case .videos:
            return assets.filter { $0.isVideo }
        case .livePhotos:
            return assets.filter { $0.isLivePhoto }
        case .screenshots:
            // Use system screenshot subtype detection (available since iOS 9+)
            // This is more efficient and accurate than manual aspect ratio checks
            return assets.filter { $0.asset.mediaSubtypes.contains(.photoScreenshot) }
        }
    }
    
    /// Apply media filter without category filter
    func applyFilters() {
        var filtered = applyMediaFilter(to: allUnsortedAssets)
        filtered = applyDateFilter(to: filtered)
        filtered = applySortOrder(to: filtered)
        
        unsortedAssets = filtered
        currentIndex = 0
        updateCurrentAsset()
        // isComplete reflects actual sorting completion, not filtered results
        isComplete = allUnsortedAssets.isEmpty
    }
    
    /// Applies a category filter to show only assets in the specified category.
    ///
    /// This method filters assets to show only those that have been sorted into
    /// the specified category (Keep, Delete, or Favorite). Passing `nil`
    /// removes the category filter.
    ///
    /// - Parameters:
    ///   - category: The category to filter by, or `nil` to remove the filter
    ///   - sortStore: The sort store to query for category information
    @MainActor
    func applyCategoryFilter(_ category: SortCategory?, sortStore: SortResultStore) {
        selectedCategoryFilter = category
        applyFiltersWithCategory(sortStore: sortStore)
    }
    
    /// Apply filters including category filter
    @MainActor
    func applyFiltersWithCategory(sortStore: SortResultStore) {
        // Filter from all assets when category filter is set, otherwise from unsorted only
        let sourceAssets = selectedCategoryFilter != nil ? allAssets : allUnsortedAssets
        var filtered = applyMediaFilter(to: sourceAssets)
        
        // Apply category filter
        if let category = selectedCategoryFilter {
            if category == .delete {
                // For delete filter, show both deleted and queued-for-delete assets
                let deleteQueueIDs = Set(deleteQueue.map { $0.id })
                filtered = filtered.filter { asset in
                    sortStore.category(for: asset.id) == .delete || deleteQueueIDs.contains(asset.id)
                }
            } else {
                filtered = filtered.filter { asset in
                    sortStore.category(for: asset.id) == category
                }
            }
        }
        
        // Apply date filter and sort order
        filtered = applyDateFilter(to: filtered)
        filtered = applySortOrder(to: filtered)
        
        unsortedAssets = filtered
        currentIndex = 0
        updateCurrentAsset()
        // isComplete reflects actual sorting completion, not filtered results
        isComplete = allUnsortedAssets.isEmpty
    }
    
    /// Apply date filter to assets
    private func applyDateFilter(to assets: [PhotoAsset]) -> [PhotoAsset] {
        let calendar = Calendar.current
        
        // Single date filter
        if let selectedDate = selectedDate {
            return assets.filter { asset in
                guard let assetDate = asset.creationDate else { return false }
                return calendar.isDate(assetDate, inSameDayAs: selectedDate)
            }
        }
        
        // Date range filter
        if let startDate = dateRangeStart, let endDate = dateRangeEnd {
            let startOfDay = calendar.startOfDay(for: startDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
            
            return assets.filter { asset in
                guard let assetDate = asset.creationDate else { return false }
                return assetDate >= startOfDay && assetDate < endOfDay
            }
        }
        
        return assets
    }
    
    /// Apply sort order to assets
    private func applySortOrder(to assets: [PhotoAsset]) -> [PhotoAsset] {
        assets.sorted { a, b in
            let dateA = a.creationDate ?? .distantPast
            let dateB = b.creationDate ?? .distantPast
            return sortOrder == .newestFirst ? dateA > dateB : dateA < dateB
        }
    }
    
    /// Toggle sort order and reapply filters
    @MainActor
    func toggleSortOrder(sortStore: SortResultStore) {
        sortOrder.toggle()
        applyFiltersWithCategory(sortStore: sortStore)
    }
    
    /// Set date filter and reapply filters
    @MainActor
    func setDateFilter(_ date: Date?, sortStore: SortResultStore) {
        selectedDate = date
        // Clear range filter when setting single date
        dateRangeStart = nil
        dateRangeEnd = nil
        applyFiltersWithCategory(sortStore: sortStore)
    }
    
    /// Set date range filter and reapply filters
    @MainActor
    func setDateRangeFilter(start: Date?, end: Date?, sortStore: SortResultStore) {
        dateRangeStart = start
        dateRangeEnd = end
        // Clear single date filter when setting range
        selectedDate = nil
        applyFiltersWithCategory(sortStore: sortStore)
    }
    
    /// Clear all date filters
    @MainActor
    func clearDateFilter(sortStore: SortResultStore) {
        selectedDate = nil
        dateRangeStart = nil
        dateRangeEnd = nil
        applyFiltersWithCategory(sortStore: sortStore)
    }
    
    /// Removes an asset from both the filtered and all unsorted asset lists.
    ///
    /// This method efficiently removes an asset using O(n) operations instead of
    /// O(n²) operations. The asset is removed from both `unsortedAssets` and
    /// `allUnsortedAssets` arrays.
    ///
    /// - Parameter asset: The asset to remove
    func removeAsset(_ asset: PhotoAsset) {
        let assetID = asset.id
        // Remove from unsortedAssets using firstIndex for O(n) instead of removeAll's O(n²)
        if let index = unsortedAssets.firstIndex(where: { $0.id == assetID }) {
            unsortedAssets.remove(at: index)
            // Adjust currentIndex: clamp to valid range or 0 if empty
            if unsortedAssets.isEmpty {
                currentIndex = 0
            } else if currentIndex >= unsortedAssets.count {
                currentIndex = unsortedAssets.count - 1
            }
        }
        // Remove from allUnsortedAssets
        if let index = allUnsortedAssets.firstIndex(where: { $0.id == assetID }) {
            allUnsortedAssets.remove(at: index)
        }
        // Keep in allAssets for category filter display
    }
    
    /// Restores an asset to the unsorted lists.
    ///
    /// This method is used when undoing a sort action. The asset is added back
    /// to both `unsortedAssets` and `allUnsortedAssets` arrays.
    ///
    /// - Parameters:
    ///   - asset: The asset to restore
    ///   - atStart: If `true`, inserts at the beginning; otherwise appends at the end
    func restoreAssetToUnsorted(_ asset: PhotoAsset, atStart: Bool = false) {
        if !unsortedAssets.contains(where: { $0.id == asset.id }) {
            if atStart {
                unsortedAssets.insert(asset, at: 0)
            } else {
                unsortedAssets.append(asset)
            }
        }
        if !allUnsortedAssets.contains(where: { $0.id == asset.id }) {
            if atStart {
                allUnsortedAssets.insert(asset, at: 0)
            } else {
                allUnsortedAssets.append(asset)
            }
        }
    }
}
