//
//  PhotoAsset.swift
//  Sift
//
//  PHAsset wrapper for type-safe photo library access
//

import Foundation
@preconcurrency import Photos
import AVFoundation
import UniformTypeIdentifiers

/// Wrapper around PHAsset providing convenient access to asset properties.
///
/// This struct provides a type-safe, Sendable wrapper around PHAsset with
/// convenient computed properties for common asset characteristics like media type,
/// RAW format detection, and burst photo identification.
struct PhotoAsset: Identifiable, Sendable {
    /// The unique identifier for this asset (PHAsset's localIdentifier)
    let id: String
    
    /// The underlying PHAsset object
    let asset: PHAsset
    
    // Cache for expensive computations
    private let _isRAWCached: Bool?
    
    /// Creates a new PhotoAsset wrapper.
    ///
    /// - Parameters:
    ///   - asset: The PHAsset to wrap
    ///   - isRAWCached: Optional pre-computed RAW status for performance optimization
    init(asset: PHAsset, isRAWCached: Bool? = nil) {
        self.asset = asset
        self.id = asset.localIdentifier
        self._isRAWCached = isRAWCached
    }
    
    // MARK: - Media Type Properties
    
    /// Returns `true` if the asset is a photo (not a video).
    var isImage: Bool {
        asset.mediaType == .image
    }
    
    /// Returns `true` if the asset is a video.
    var isVideo: Bool {
        asset.mediaType == .video
    }
    
    /// Returns `true` if the asset is a Live Photo.
    var isLivePhoto: Bool {
        asset.mediaSubtypes.contains(.photoLive)
    }
    
    /// Returns `true` if the asset is a RAW image.
    ///
    /// This property checks the asset's resources to determine if it contains
    /// RAW image data. The check is performed by examining the uniform type
    /// identifier (UTI) of the asset resources.
    ///
    /// - Note: This computation can be expensive. For better performance, consider
    ///   pre-computing this value and passing it via `isRAWCached` in the initializer.
    var isRAW: Bool {
        // Return cached value if available
        if let cached = _isRAWCached {
            return cached
        }
        
        // Compute and cache the result (note: struct is value type, so this won't persist across copies)
        // For better performance, compute this once during asset creation
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.contains { resource in
            // Check if resource type is alternate photo or full size photo
            if resource.type == .alternatePhoto || resource.type == .fullSizePhoto {
                let utiString = resource.uniformTypeIdentifier
                guard let uti = UTType(utiString) else {
                    // Fallback: check common RAW file extensions in UTI string
                    return utiString.contains("raw") || 
                           utiString.contains("dng") ||
                           utiString.contains("cr2") ||
                           utiString.contains("nef") ||
                           utiString.contains("arw")
                }
                
                // Check if UTI conforms to camera-raw-image type
                if let cameraRawType = UTType("public.camera-raw-image"),
                   uti.conforms(to: cameraRawType) {
                    return true
                }
                
                // Also check common RAW file extensions
                if utiString.contains("raw") || 
                   utiString.contains("dng") ||
                   utiString.contains("cr2") ||
                   utiString.contains("nef") ||
                   utiString.contains("arw") {
                    return true
                }
            }
            return false
        }
    }
    
    /// Returns `true` if the asset is part of a burst photo sequence.
    var isBurstPhoto: Bool {
        // Burst photos have a non-nil burstIdentifier
        asset.burstIdentifier != nil
    }
    
    /// Returns the burst identifier if this asset is part of a burst sequence.
    ///
    /// All photos in the same burst sequence share the same burst identifier.
    /// Returns `nil` if the asset is not part of a burst sequence.
    var burstIdentifier: String? {
        asset.burstIdentifier
    }
    
    // MARK: - Date Properties
    
    /// Returns the creation date of the asset.
    ///
    /// This is the date when the photo or video was originally captured.
    var creationDate: Date? {
        asset.creationDate
    }
    
    // MARK: - Video Properties
    
    /// Returns a formatted duration string for video assets.
    ///
    /// The format is "HH:MM:SS" for videos longer than an hour, or "MM:SS" for shorter videos.
    /// Returns an empty string if the asset is not a video.
    var formattedDuration: String {
        guard isVideo else { return "" }
        let duration = asset.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
