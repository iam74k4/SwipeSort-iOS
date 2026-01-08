//
//  SortingState.swift
//  SwipeSort
//
//  State for the sorting feature
//

import SwiftUI
import PhotosUI

@Observable
final class SortingState {
    // MARK: - Assets
    
    var unsortedAssets: [PhotoAsset] = []
    var currentIndex: Int = 0
    var currentAsset: PhotoAsset?
    
    var totalCount: Int = 0
    
    var isComplete: Bool = false
    
    // MARK: - Image Loading
    
    var currentImage: UIImage?
    var nextImage: UIImage?
    var isLoadingImage: Bool = false
    
    // MARK: - Live Photo
    
    var currentLivePhoto: PHLivePhoto?
    var isPlayingLivePhoto: Bool = false
    var isLongPressing: Bool = false
    
    // MARK: - Burst Photos
    
    var showingBurstSelector: Bool = false
    var burstAssets: [PhotoAsset] = []
    var currentBurstCount: Int?
    
    // MARK: - Swipe State
    
    var offset: CGSize = .zero
    var swipeDirection: SwipeDirection = .none
    var isAnimatingOut: Bool = false
    var imageOpacity: Double = 1.0
    
    // MARK: - Double Tap (Favorite)
    
    var showHeartAnimation: Bool = false
    
    // MARK: - Computed
    
    var swipeProgress: Double {
        let horizontal = abs(offset.width) / SwipeThreshold.horizontal
        return min(horizontal, 1.0)
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
    }
    
    func reset() {
        offset = .zero
        swipeDirection = .none
        isAnimatingOut = false
        imageOpacity = 1.0
        isPlayingLivePhoto = false
        isLongPressing = false
    }
    
    func resetBurstSelector() {
        showingBurstSelector = false
        burstAssets = []
    }
}
