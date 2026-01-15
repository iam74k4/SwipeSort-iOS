//
//  PhotoLibraryClient.swift
//  SwipeSort
//
//  Photo library access with dependency injection
//

import Foundation
@preconcurrency import Photos
import PhotosUI
import AVFoundation
import UIKit
import SwiftUI
import os

// MARK: - Photo Library Client

@MainActor
@Observable
final class PhotoLibraryClient {
    // MARK: - Logger
    
    private nonisolated let logger = Logger(subsystem: "com.swipesort", category: "PhotoLibrary")
    
    // MARK: - Observable State
    
    var isLoading = false
    var allAssets: [PhotoAsset] = []
    var loadingProgress: Double = 0
    
    // MARK: - Private Properties
    
    private nonisolated let imageManager = PHCachingImageManager()
    
    // MARK: - Constants
    
    private static nonisolated let cacheAheadCount = 5
    private static nonisolated let defaultTargetSize = CGSize(width: 1200, height: 1200)
    
    /// Timeout for full-size image loading (longer for iCloud downloads)
    private static nonisolated let imageLoadTimeout: TimeInterval = 30
    /// Timeout for thumbnail loading (faster, local-only preferred)
    private static nonisolated let thumbnailLoadTimeout: TimeInterval = 10
    /// Timeout for Live Photo loading (may require iCloud download)
    private static nonisolated let livePhotoLoadTimeout: TimeInterval = 30
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Fetch All Assets
    
    func fetchAllAssets() async -> [PhotoAsset] {
        isLoading = true
        loadingProgress = 0
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        
        let result = PHAsset.fetchAssets(with: fetchOptions)
        
        var assets: [PhotoAsset] = []
        assets.reserveCapacity(result.count)
        
        result.enumerateObjects { asset, _, _ in
            assets.append(PhotoAsset(asset: asset))
        }
        
        allAssets = assets
        loadingProgress = 1.0
        isLoading = false
        
        logger.info("Fetched \(result.count) assets")
        
        return assets
    }
    
    // MARK: - Image Loading (nonisolated to avoid MainActor issues in callbacks)
    
    /// Load image with optional RAW optimization
    /// For RAW images, uses embedded preview for faster initial display
    nonisolated func loadImage(for asset: PHAsset, targetSize: CGSize? = nil, preferFastPreview: Bool = false) async -> UIImage? {
        let size = targetSize ?? CGSize(width: 1200, height: 1200)
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        if preferFastPreview {
            // For RAW images: prioritize embedded JPEG preview
            options.version = .current
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
        } else {
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
        }
        
        // Use a class to safely capture mutable state
        final class ImageLoadState: @unchecked Sendable {
            var hasResumed = false
            var lastImage: UIImage?
            let lock = NSLock()
        }
        let state = ImageLoadState()
        
        return await withCheckedContinuation { continuation in
            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                state.lock.lock()
                defer { state.lock.unlock() }
                
                guard !state.hasResumed else { return }
                
                if let image = image {
                    state.lastImage = image
                }
                
                let isError = info?[PHImageErrorKey] != nil
                let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                let isResultFinal = info?[PHImageResultIsInCloudKey] as? Bool == false || !isDegraded
                
                if isError || isCancelled || !isDegraded || isResultFinal {
                    state.hasResumed = true
                    continuation.resume(returning: state.lastImage)
                }
            }
            
            // Safety timeout - prevents hanging on slow/failed network requests
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.imageLoadTimeout) { [weak self] in
                state.lock.lock()
                defer { state.lock.unlock() }
                if !state.hasResumed {
                    state.hasResumed = true
                    self?.imageManager.cancelImageRequest(requestID)
                    self?.logger.warning("Image load timeout after \(Self.imageLoadTimeout)s for asset \(asset.localIdentifier)")
                    continuation.resume(returning: state.lastImage)
                }
            }
        }
    }
    
    nonisolated func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        let thumbnailSize = CGSize(width: 200, height: 200)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        final class ThumbnailLoadState: @unchecked Sendable {
            var hasResumed = false
            let lock = NSLock()
        }
        let state = ThumbnailLoadState()
        
        return await withCheckedContinuation { continuation in
            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                state.lock.lock()
                defer { state.lock.unlock() }
                
                guard !state.hasResumed else { return }
                
                let isError = info?[PHImageErrorKey] != nil
                let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                
                if isError || isCancelled {
                    state.hasResumed = true
                    continuation.resume(returning: nil)
                    return
                }
                
                if let image = image {
                    state.hasResumed = true
                    continuation.resume(returning: image)
                }
            }
            
            // Safety timeout - thumbnails should load quickly, timeout faster than full images
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.thumbnailLoadTimeout) { [weak self] in
                state.lock.lock()
                defer { state.lock.unlock() }
                if !state.hasResumed {
                    state.hasResumed = true
                    self?.imageManager.cancelImageRequest(requestID)
                    self?.logger.warning("Thumbnail load timeout after \(Self.thumbnailLoadTimeout)s for asset \(asset.localIdentifier)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Live Photo Loading
    
    nonisolated func loadLivePhoto(for asset: PHAsset, targetSize: CGSize) async -> PHLivePhoto? {
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        final class LivePhotoLoadState: @unchecked Sendable {
            var hasResumed = false
            var lastLivePhoto: PHLivePhoto?
            let lock = NSLock()
        }
        let state = LivePhotoLoadState()
        
        return await withCheckedContinuation { continuation in
            let requestID = imageManager.requestLivePhoto(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { livePhoto, info in
                state.lock.lock()
                defer { state.lock.unlock() }
                
                guard !state.hasResumed else { return }
                
                if let livePhoto = livePhoto {
                    state.lastLivePhoto = livePhoto
                }
                
                let isError = info?[PHImageErrorKey] != nil
                let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if isError || isCancelled || !isDegraded {
                    state.hasResumed = true
                    continuation.resume(returning: state.lastLivePhoto)
                }
            }
            
            // Safety timeout - Live Photos may require iCloud download
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.livePhotoLoadTimeout) { [weak self] in
                state.lock.lock()
                defer { state.lock.unlock() }
                if !state.hasResumed {
                    state.hasResumed = true
                    self?.imageManager.cancelImageRequest(requestID)
                    self?.logger.warning("Live Photo load timeout after \(Self.livePhotoLoadTimeout)s for asset \(asset.localIdentifier)")
                    continuation.resume(returning: state.lastLivePhoto)
                }
            }
        }
    }

    // MARK: - Video Loading

    nonisolated func loadVideoPlayerItem(for asset: PHAsset) async -> AVPlayerItem? {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic

        return await withCheckedContinuation { continuation in
            imageManager.requestPlayerItem(forVideo: asset, options: options) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }
    
    // MARK: - Burst Photos
    
    /// Fetch all photos in a burst sequence
    nonisolated func fetchBurstAssets(for burstIdentifier: String) -> [PhotoAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "burstIdentifier == %@", burstIdentifier)
        options.includeAllBurstAssets = true
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PhotoAsset] = []
        assets.reserveCapacity(result.count)
        
        result.enumerateObjects { asset, _, _ in
            assets.append(PhotoAsset(asset: asset))
        }
        
        return assets
    }
    
    // MARK: - Deletion
    
    nonisolated func deleteAssets(_ assets: [PHAsset]) async throws {
        // Capture assets for use in nonisolated context
        let assetsToDelete = assets
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
        }
        
        // Update cache on MainActor
        let idsToDelete = Set(assets.map { $0.localIdentifier })
        await MainActor.run {
            self.allAssets.removeAll { idsToDelete.contains($0.id) }
        }
        
        logger.info("Deleted \(assets.count) assets")
    }
    
    // MARK: - Favorites
    
    /// Set the favorite status for an asset in iOS Photos
    nonisolated func setFavorite(_ asset: PHAsset, isFavorite: Bool) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = isFavorite
        }
        
        logger.info("Set favorite=\(isFavorite) for asset \(asset.localIdentifier)")
    }
    
    /// Set favorite status for multiple assets
    nonisolated func setFavorite(_ assets: [PHAsset], isFavorite: Bool) async throws {
        guard !assets.isEmpty else { return }
        
        try await PHPhotoLibrary.shared().performChanges {
            for asset in assets {
                let request = PHAssetChangeRequest(for: asset)
                request.isFavorite = isFavorite
            }
        }
        
        logger.info("Set favorite=\(isFavorite) for \(assets.count) assets")
    }
    
    /// Remove assets from cache by IDs (used when assets are deleted externally)
    func removeFromCache(ids: Set<String>) {
        allAssets.removeAll { ids.contains($0.id) }
    }
    
    // MARK: - Caching
    
    nonisolated func updateCacheWindow(currentIndex: Int, assets: [PhotoAsset]) {
        guard !assets.isEmpty else { return }
        
        let endIndex = min(currentIndex + Self.cacheAheadCount, assets.count)
        guard currentIndex < endIndex else { return }
        
        let assetsToCache = assets[currentIndex..<endIndex].map { $0.asset }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        imageManager.startCachingImages(
            for: assetsToCache,
            targetSize: Self.defaultTargetSize,
            contentMode: .aspectFit,
            options: options
        )
    }
    
    // MARK: - Helpers
    
    func unsortedAssets(excluding sortedIDs: Set<String>) -> [PhotoAsset] {
        allAssets.filter { !sortedIDs.contains($0.id) }
    }
    
    func assets(for ids: [String]) -> [PhotoAsset] {
        let idSet = Set(ids)
        return allAssets.filter { idSet.contains($0.id) }
    }
}
