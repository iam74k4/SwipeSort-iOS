//
//  SortingState.swift
//  SwipeSort
//
//  State for the sorting feature
//

import SwiftUI

@Observable
final class SortingState {
    // MARK: - Assets
    
    var unsortedAssets: [PhotoAsset] = []
    var currentIndex: Int = 0
    var currentAsset: PhotoAsset?
    
    var totalCount: Int = 0
    var sortedCount: Int = 0
    
    var isComplete: Bool = false
    
    // MARK: - Image Loading
    
    var currentImage: UIImage?
    var nextImage: UIImage?
    var isLoadingImage: Bool = false
    
    // MARK: - Swipe State
    
    var offset: CGSize = .zero
    var swipeDirection: SwipeDirection = .none
    var isAnimatingOut: Bool = false
    var imageOpacity: Double = 1.0
    
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
        } else if currentIndex < unsortedAssets.count {
            currentAsset = unsortedAssets[currentIndex]
        } else {
            currentIndex = 0
            currentAsset = unsortedAssets.first
        }
    }
    
    func reset() {
        offset = .zero
        swipeDirection = .none
        isAnimatingOut = false
        imageOpacity = 1.0
    }
}
