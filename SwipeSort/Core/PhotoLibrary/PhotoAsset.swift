//
//  PhotoAsset.swift
//  SwipeSort
//
//  Wrapper for PHAsset with convenience methods
//

import Foundation
import Photos

/// Represents a photo or video asset
struct PhotoAsset: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let asset: PHAsset
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
    }
    
    var isVideo: Bool {
        asset.mediaType == .video
    }
    
    var isImage: Bool {
        asset.mediaType == .image
    }
    
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
    
    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
