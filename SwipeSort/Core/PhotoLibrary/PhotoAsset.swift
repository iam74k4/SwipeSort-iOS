//
//  PhotoAsset.swift
//  SwipeSort
//
//  PHAsset wrapper for type-safe photo library access
//

import Foundation
@preconcurrency import Photos
import AVFoundation
import UniformTypeIdentifiers

/// Wrapper around PHAsset providing convenient access to asset properties
struct PhotoAsset: Identifiable, Sendable {
    let id: String
    let asset: PHAsset
    
    init(asset: PHAsset) {
        self.asset = asset
        self.id = asset.localIdentifier
    }
    
    // MARK: - Media Type Properties
    
    var isImage: Bool {
        asset.mediaType == .image
    }
    
    var isVideo: Bool {
        asset.mediaType == .video
    }
    
    var isLivePhoto: Bool {
        asset.mediaSubtypes.contains(.photoLive)
    }
    
    var isRAW: Bool {
        // Check if asset has RAW resources
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
    
    var isBurstPhoto: Bool {
        // Burst photos have a non-nil burstIdentifier
        asset.burstIdentifier != nil
    }
    
    var burstIdentifier: String? {
        asset.burstIdentifier
    }
    
    // MARK: - Date Properties
    
    var creationDate: Date? {
        asset.creationDate
    }
    
    // MARK: - Video Properties
    
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
