//
//  SortingState.swift
//  SwipeSort
//
//  State for the sorting feature
//

import SwiftUI
import PhotosUI
import AVFoundation

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
    var selectedCategoryFilter: SortCategory? = nil  // カテゴリフィルター（統計ピルで選択）
    
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
    
    // MARK: - Burst Photos
    
    var showingBurstSelector: Bool = false
    var burstAssets: [PhotoAsset] = []
    var currentBurstCount: Int?
    
    // MARK: - Delete Queue (batch delete to reduce iOS confirmation dialogs)
    
    var deleteQueue: [PhotoAsset] = []
    static let batchDeleteThreshold = 5
    
    // MARK: - Swipe State
    
    var offset: CGSize = .zero
    var swipeDirection: SwipeDirection = .none
    var isAnimatingOut: Bool = false
    var imageOpacity: Double = 1.0
    
    // MARK: - Undo State
    
    var isUndoing: Bool = false  // Undo処理中フラグ（連打防止）
    
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
        
        // Reset Live Photo state when changing asset
        currentLivePhoto = nil
        isPlayingLivePhoto = false
        isPlayingVideo = false
    }
    
    func reset() {
        offset = .zero
        swipeDirection = .none
        isAnimatingOut = false
        imageOpacity = 1.0
        isPlayingLivePhoto = false
        isLongPressing = false
        isPlayingVideo = false
    }
    
    func resetBurstSelector() {
        showingBurstSelector = false
        burstAssets = []
    }
    
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
            return assets.filter { asset in
                guard asset.isImage else { return false }
                
                let width = asset.asset.pixelWidth
                let height = asset.asset.pixelHeight
                guard width > 0, height > 0 else { return false }
                
                // Calculate aspect ratio
                let aspectRatio = Double(height) / Double(width)
                
                // iOS screenshots typically have portrait aspect ratios around 2.16 (19.5:9) or 2.17 (16:9)
                // Common ratios: ~2.16 (iPhone X and newer), ~1.78 (iPhone 6/7/8), ~2.17 (some models)
                // Allow some tolerance for different models and orientations
                let isPortraitScreenshot = aspectRatio >= 2.0 && aspectRatio <= 2.3
                let isLandscapeScreenshot = aspectRatio >= 0.43 && aspectRatio <= 0.5  // Inverse of portrait
                
                // Also check for common screenshot pixel dimensions (for exact matches)
                // This helps catch edge cases where aspect ratio alone might not be enough
                let commonDimensions: Set<Int> = [
                    width * 10000 + height,  // Encode as single number for efficient comparison
                    1170 * 10000 + 2532,     // iPhone 12/13/14
                    1284 * 10000 + 2778,     // iPhone 12/13/14 Pro Max
                    1179 * 10000 + 2556,     // iPhone 14 Pro
                    1290 * 10000 + 2796,     // iPhone 14 Pro Max
                    1125 * 10000 + 2436,     // iPhone X/XS/11 Pro
                    1242 * 10000 + 2688,     // iPhone XS Max/11 Pro Max
                    828 * 10000 + 1792,      // iPhone XR/11
                    750 * 10000 + 1334,      // iPhone 6/7/8
                    1080 * 10000 + 1920,     // iPhone 6+/7+/8+
                    // Landscape variants
                    2532 * 10000 + 1170,
                    2778 * 10000 + 1284,
                    2556 * 10000 + 1179,
                    2796 * 10000 + 1290,
                    2436 * 10000 + 1125,
                    2688 * 10000 + 1242,
                    1792 * 10000 + 828,
                    1334 * 10000 + 750,
                    1920 * 10000 + 1080
                ]
                
                return (isPortraitScreenshot || isLandscapeScreenshot) || commonDimensions.contains(width * 10000 + height)
            }
        }
    }
    
    /// Apply both media filter and category filter (without category filter)
    func applyFilters() {
        let filtered = applyMediaFilter(to: allUnsortedAssets)
        
        unsortedAssets = filtered
        currentIndex = 0
        updateCurrentAsset()
        // isCompleteは実際にすべてのアセットが整理された場合のみtrue（フィルター結果ではない）
        isComplete = allUnsortedAssets.isEmpty
    }
    
    /// Apply category filter (called from SortingFeature with sortStore)
    @MainActor
    func applyCategoryFilter(_ category: SortCategory?, sortStore: SortResultStore) {
        selectedCategoryFilter = category
        applyFiltersWithCategory(sortStore: sortStore)
    }
    
    /// Apply filters including category filter
    @MainActor
    func applyFiltersWithCategory(sortStore: SortResultStore) {
        // カテゴリフィルターが設定されている場合は全アセットから、そうでない場合は未整理アセットのみからフィルタリング
        let sourceAssets = selectedCategoryFilter != nil ? allAssets : allUnsortedAssets
        var filtered = applyMediaFilter(to: sourceAssets)
        
        // Apply category filter
        if let category = selectedCategoryFilter {
            filtered = filtered.filter { asset in
                sortStore.category(for: asset.id) == category
            }
        }
        
        unsortedAssets = filtered
        currentIndex = 0
        updateCurrentAsset()
        // isCompleteは実際にすべてのアセットが整理された場合のみtrue（フィルター結果ではない）
        isComplete = allUnsortedAssets.isEmpty
    }
    
    /// Remove an asset from both filtered and all lists
    /// Optimized: Use single loop instead of two separate removeAll calls
    func removeAsset(_ asset: PhotoAsset) {
        let assetID = asset.id
        // Remove from unsortedAssets using firstIndex for O(n) instead of removeAll's O(n²)
        if let index = unsortedAssets.firstIndex(where: { $0.id == assetID }) {
            unsortedAssets.remove(at: index)
        }
        // Remove from allUnsortedAssets
        if let index = allUnsortedAssets.firstIndex(where: { $0.id == assetID }) {
            allUnsortedAssets.remove(at: index)
        }
        // allAssetsからは削除しない（カテゴリフィルターで表示するため）
    }
    
    /// Move asset to end (for skip)
    func moveToEnd(_ asset: PhotoAsset) {
        unsortedAssets.removeAll { $0.id == asset.id }
        unsortedAssets.append(asset)
        // Also move in all assets
        allUnsortedAssets.removeAll { $0.id == asset.id }
        allUnsortedAssets.append(asset)
    }
    
    /// Restore an asset to unsorted lists (both filtered and all)
    /// - Parameters:
    ///   - asset: The asset to restore
    ///   - atStart: If true, insert at the beginning; otherwise append at the end
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
