//
//  PhotoAsset.swift
//  SwipeSort
//
//  Wrapper for PHAsset with convenience methods
//

import Foundation
import Photos
import UniformTypeIdentifiers

/// Represents a photo or video asset
struct PhotoAsset: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let asset: PHAsset
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
    }
    
    // MARK: - Media Type
    
    var isVideo: Bool {
        asset.mediaType == .video
    }
    
    var isImage: Bool {
        asset.mediaType == .image
    }
    
    // MARK: - Special Photo Types
    
    /// True if this is a Live Photo
    var isLivePhoto: Bool {
        asset.mediaSubtypes.contains(.photoLive)
    }
    
    /// True if this is a RAW image (ProRAW, DNG, etc.)
    var isRAW: Bool {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.contains { resource in
            if let uti = UTType(resource.uniformTypeIdentifier) {
                return uti.conforms(to: .rawImage)
            }
            return false
        }
    }
    
    /// True if this is a HEIC image
    var isHEIC: Bool {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.contains { resource in
            resource.uniformTypeIdentifier == UTType.heic.identifier
        }
    }
    
    // MARK: - Burst Photos
    
    /// True if this photo is part of a burst sequence
    var isBurstPhoto: Bool {
        asset.burstIdentifier != nil
    }
    
    /// The burst identifier for grouping burst photos
    var burstIdentifier: String? {
        asset.burstIdentifier
    }
    
    /// True if this is the representative photo of a burst sequence
    var representsBurst: Bool {
        asset.representsBurst
    }
    
    // MARK: - Metadata
    
    var creationDate: Date? {
        asset.creationDate
    }
    
    var duration: TimeInterval {
        asset.duration
    }
    
    var formattedDuration: String {
        guard isVideo else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var aspectRatio: CGFloat {
        guard asset.pixelWidth > 0 else { return 1 }
        return CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
    }
    
    // MARK: - Equatable & Hashable
    
    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
