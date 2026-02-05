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

// MARK: - Cache State

/// Nonisolated class to store cache state (since @Observable classes can't have nonisolated vars)
private final class CacheState: @unchecked Sendable {
    var cachedAssets: Set<PHAsset> = []
    let lock = NSLock()
}

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
    
    // Track currently cached assets to stop old cache when window moves
    private nonisolated let cacheState = CacheState()
    
    // MARK: - Constants
    
    private static nonisolated let cacheAheadCount = 5
    private static nonisolated let defaultTargetSize = CGSize(width: 1200, height: 1200)
    
    /// Timeout for full-size image loading (longer for iCloud downloads)
    private static nonisolated let imageLoadTimeout: TimeInterval = 30
    /// Timeout for thumbnail loading (faster, local-only preferred)
    private static nonisolated let thumbnailLoadTimeout: TimeInterval = 10
    /// Timeout for Live Photo loading (may require iCloud download)
    private static nonisolated let livePhotoLoadTimeout: TimeInterval = 30
    /// Timeout for video player item loading (may require iCloud download)
    private static nonisolated let videoLoadTimeout: TimeInterval = 30
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Fetch All Assets
    
    /// Fetches all photos and videos from the user's photo library.
    ///
    /// This method fetches all assets sorted by creation date (newest first) and updates
    /// the `allAssets` property and loading progress. The method is async and should be
    /// called from the main actor context.
    ///
    /// - Returns: An array of `PhotoAsset` objects representing all photos and videos
    /// - Note: This method requires photo library access permission
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
    
    /// Loads an image for the specified photo asset.
    ///
    /// This method loads an image asynchronously with optional RAW optimization.
    /// For RAW images, setting `preferFastPreview` to `true` uses the embedded JPEG
    /// preview for faster initial display.
    ///
    /// - Parameters:
    ///   - asset: The PHAsset to load the image for
    ///   - targetSize: Optional target size for the image. Defaults to 1200x1200 if nil
    ///   - preferFastPreview: If `true`, prioritizes fast preview for RAW images
    /// - Returns: The loaded UIImage, or `nil` if loading fails or times out
    /// - Note: This method includes a timeout mechanism (30 seconds) to prevent hanging
    ///   on slow network requests. Network access is allowed for iCloud photos.
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
    
    /// Loads a thumbnail image for the specified photo asset.
    ///
    /// This method loads a small thumbnail (200x200) optimized for quick display
    /// in lists or previews. The method returns immediately when a non-degraded
    /// image is available.
    ///
    /// - Parameter asset: The PHAsset to load the thumbnail for
    /// - Returns: The loaded thumbnail UIImage, or `nil` if loading fails or times out
    /// - Note: This method includes a timeout mechanism (10 seconds) and returns
    ///   the last available image (even if degraded) if the timeout is reached.
    nonisolated func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        let thumbnailSize = CGSize(width: 200, height: 200)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        final class ThumbnailLoadState: @unchecked Sendable {
            var hasResumed = false
            var lastImage: UIImage?
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
                
                // Store image if available (even if degraded)
                if let image = image {
                    state.lastImage = image
                }
                
                let isError = info?[PHImageErrorKey] != nil
                let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                // Early return on error or cancellation (don't wait for timeout)
                if isError || isCancelled {
                    state.hasResumed = true
                    self.logger.warning("Thumbnail load failed: error=\(isError), cancelled=\(isCancelled) for asset \(asset.localIdentifier)")
                    continuation.resume(returning: nil)
                    return
                }
                
                // Return immediately when we have a non-degraded image
                if let image = image, !isDegraded {
                    state.hasResumed = true
                    continuation.resume(returning: image)
                    return
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
                    // Return last image if available (even if degraded), otherwise nil
                    continuation.resume(returning: state.lastImage)
                }
            }
        }
    }
    
    // MARK: - Live Photo Loading
    
    /// Loads a Live Photo for the specified photo asset.
    ///
    /// This method loads both the image and video components of a Live Photo
    /// asynchronously. Network access is allowed for iCloud photos.
    ///
    /// - Parameters:
    ///   - asset: The PHAsset to load the Live Photo for
    ///   - targetSize: Target size for the Live Photo
    /// - Returns: The loaded PHLivePhoto, or `nil` if loading fails or times out
    /// - Note: This method includes a timeout mechanism (30 seconds) to prevent
    ///   hanging on slow network requests.
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

        final class VideoLoadState: @unchecked Sendable {
            var hasResumed = false
            var lastItem: AVPlayerItem?
            let lock = NSLock()
        }
        let state = VideoLoadState()

        return await withCheckedContinuation { continuation in
            let requestID = imageManager.requestPlayerItem(forVideo: asset, options: options) { item, _ in
                state.lock.lock()
                defer { state.lock.unlock() }
                guard !state.hasResumed else { return }
                state.hasResumed = true
                state.lastItem = item
                continuation.resume(returning: item)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + Self.videoLoadTimeout) { [weak self] in
                state.lock.lock()
                defer { state.lock.unlock() }
                if !state.hasResumed {
                    state.hasResumed = true
                    self?.imageManager.cancelImageRequest(requestID)
                    self?.logger.warning("Video load timeout after \(Self.videoLoadTimeout)s for asset \(asset.localIdentifier)")
                    continuation.resume(returning: state.lastItem)
                }
            }
        }
    }
    
    // MARK: - Burst Photos
    
    /// Fetches all photos in a burst sequence.
    ///
    /// This method retrieves all photos that belong to the same burst sequence
    /// identified by the burst identifier. Photos are sorted by creation date
    /// (oldest first).
    ///
    /// - Parameter burstIdentifier: The burst identifier string from a burst photo
    /// - Returns: An array of `PhotoAsset` objects representing all photos in the burst
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
    
    /// Deletes the specified assets from the photo library.
    ///
    /// This method permanently deletes assets from the user's photo library.
    /// Deleted assets are moved to the "Recently Deleted" album and can be
    /// recovered for 30 days.
    ///
    /// - Parameter assets: An array of PHAsset objects to delete
    /// - Throws: An error if deletion fails (e.g., permission denied)
    /// - Note: This method updates the `allAssets` property to remove deleted assets
    ///   from the cache. The deletion is performed in a background context.
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
    
    /// Sets the favorite status for a single asset in iOS Photos.
    ///
    /// This method updates the favorite status of an asset, which syncs with
    /// the iOS Favorites album. The change is persisted in the photo library.
    ///
    /// - Parameters:
    ///   - asset: The PHAsset to update
    ///   - isFavorite: `true` to mark as favorite, `false` to remove from favorites
    /// - Throws: An error if the operation fails (e.g., permission denied)
    nonisolated func setFavorite(_ asset: PHAsset, isFavorite: Bool) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = isFavorite
        }
        
        logger.info("Set favorite=\(isFavorite) for asset \(asset.localIdentifier)")
    }
    
    /// Sets the favorite status for multiple assets in iOS Photos.
    ///
    /// This method updates the favorite status of multiple assets in a single
    /// operation, which is more efficient than calling `setFavorite(_:isFavorite:)`
    /// multiple times.
    ///
    /// - Parameters:
    ///   - assets: An array of PHAsset objects to update
    ///   - isFavorite: `true` to mark as favorite, `false` to remove from favorites
    /// - Throws: An error if the operation fails (e.g., permission denied)
    /// - Note: If the array is empty, this method returns immediately without error
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
    
    // MARK: - Caching
    
    /// Updates the image cache window for efficient photo loading.
    ///
    /// This method manages the PHCachingImageManager cache window, starting to cache
    /// images for assets near the current index and stopping caching for assets
    /// that are no longer in the window. This improves performance by preloading
    /// images that are likely to be viewed soon.
    ///
    /// - Parameters:
    ///   - currentIndex: The current index in the assets array
    ///   - assets: The array of PhotoAsset objects currently being displayed
    /// - Note: The cache window includes the current asset and the next 5 assets
    nonisolated func updateCacheWindow(currentIndex: Int, assets: [PhotoAsset]) {
        guard !assets.isEmpty else { return }
        
        let endIndex = min(currentIndex + Self.cacheAheadCount, assets.count)
        guard currentIndex < endIndex else { return }
        
        let assetsToCache = assets[currentIndex..<endIndex].map { $0.asset }
        let assetsToCacheSet = Set(assetsToCache)
        
        cacheState.lock.lock()
        defer { cacheState.lock.unlock() }
        
        // Stop caching for assets that are no longer in the window
        let assetsToStop = cacheState.cachedAssets.subtracting(assetsToCacheSet)
        if !assetsToStop.isEmpty {
            imageManager.stopCachingImages(
                for: Array(assetsToStop),
                targetSize: Self.defaultTargetSize,
                contentMode: .aspectFit,
                options: nil
            )
        }
        
        // Start caching for new assets in the window
        let assetsToStart = assetsToCacheSet.subtracting(cacheState.cachedAssets)
        if !assetsToStart.isEmpty {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            imageManager.startCachingImages(
                for: Array(assetsToStart),
                targetSize: Self.defaultTargetSize,
                contentMode: .aspectFit,
                options: options
            )
        }
        
        // Update cached assets set
        cacheState.cachedAssets = assetsToCacheSet
    }
    
    // MARK: - Helpers
    
    func assets(for ids: [String]) -> [PhotoAsset] {
        let idSet = Set(ids)
        return allAssets.filter { idSet.contains($0.id) }
    }
    
    // MARK: - Albums
    
    /// Fetches all user-created albums from the photo library.
    ///
    /// This method returns only regular albums created by the user, excluding
    /// system albums, synced albums, and shared albums.
    ///
    /// - Returns: An array of PHAssetCollection objects representing user albums
    /// - Throws: An error if the operation fails (e.g., permission denied)
    nonisolated func fetchUserAlbums() async throws -> [PHAssetCollection] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: fetchOptions
        )
        
        var albums: [PHAssetCollection] = []
        result.enumerateObjects { collection, _, _ in
            albums.append(collection)
        }
        
        logger.info("Fetched \(albums.count) user albums")
        return albums
    }
    
    /// Creates a new album with the specified name.
    ///
    /// - Parameter name: The name for the new album
    /// - Returns: The created PHAssetCollection, or nil if creation failed
    /// - Throws: An error if the operation fails (e.g., permission denied)
    nonisolated func createAlbum(name: String) async throws -> PHAssetCollection? {
        // Check authorization
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.insufficientPermissions
        }
        
        var placeholderIdentifier: String?
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholderIdentifier = request.placeholderForCreatedAssetCollection.localIdentifier
        }
        
        // Fetch the actual collection
        var createdCollection: PHAssetCollection?
        if let identifier = placeholderIdentifier {
            let fetchResult = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier],
                options: nil
            )
            createdCollection = fetchResult.firstObject
        }
        
        logger.info("Created album: \(name)")
        return createdCollection
    }
    
    /// Adds assets to an album, skipping duplicates.
    ///
    /// This method checks if assets are already in the album before adding them,
    /// preventing duplicate entries.
    ///
    /// - Parameters:
    ///   - assets: An array of PHAsset objects to add
    ///   - album: The PHAssetCollection to add assets to
    /// - Returns: The number of assets actually added (excluding duplicates)
    /// - Throws: An error if the operation fails (e.g., permission denied)
    nonisolated func addAssets(_ assets: [PHAsset], to album: PHAssetCollection) async throws -> Int {
        // Check authorization
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.insufficientPermissions
        }
        
        guard !assets.isEmpty else { return 0 }
        
        // Check for duplicates
        let existingAssets = PHAsset.fetchAssets(in: album, options: nil)
        var existingIDs = Set<String>()
        existingAssets.enumerateObjects { asset, _, _ in
            existingIDs.insert(asset.localIdentifier)
        }
        
        // Filter out duplicates
        let assetsToAdd = assets.filter { !existingIDs.contains($0.localIdentifier) }
        
        guard !assetsToAdd.isEmpty else {
            logger.info("All assets already in album")
            return 0
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest(for: album)
            request?.addAssets(assetsToAdd as NSFastEnumeration)
        }
        
        logger.info("Added \(assetsToAdd.count) assets to album (skipped \(assets.count - assetsToAdd.count) duplicates)")
        return assetsToAdd.count
    }
    
}

// MARK: - Photo Library Errors

enum PhotoLibraryError: LocalizedError {
    case insufficientPermissions
    case albumCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return NSLocalizedString("Insufficient photo library permissions", comment: "Permission error")
        case .albumCreationFailed:
            return NSLocalizedString("Failed to create album", comment: "Album creation error")
        }
    }
}
