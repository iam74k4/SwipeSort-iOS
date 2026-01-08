//
//  MediaBadge.swift
//  SwipeSort
//
//  Badges for special media types (LIVE, RAW, BURST)
//

import SwiftUI

/// Badge type for special media
enum MediaBadgeType {
    case live
    case raw
    case burst(count: Int)
    
    var text: String {
        switch self {
        case .live: return "LIVE"
        case .raw: return "RAW"
        case .burst(let count): return "BURST \(count)"
        }
    }
    
    var icon: String {
        switch self {
        case .live: return "livephoto"
        case .raw: return "camera.aperture"
        case .burst: return "square.stack.3d.up"
        }
    }
    
    var color: Color {
        switch self {
        case .live: return .yellow
        case .raw: return .orange
        case .burst: return .cyan
        }
    }
}

/// A small badge to indicate special media types
struct MediaBadge: View {
    let type: MediaBadgeType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 10, weight: .bold))
            Text(type.text)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(type.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(Color.black.opacity(0.6))
        }
    }
}

/// Container for multiple badges
struct MediaBadgeStack: View {
    let asset: PhotoAsset
    let burstCount: Int?
    
    init(asset: PhotoAsset, burstCount: Int? = nil) {
        self.asset = asset
        self.burstCount = burstCount
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if asset.isLivePhoto {
                MediaBadge(type: .live)
            }
            
            if asset.isRAW {
                MediaBadge(type: .raw)
            }
            
            if asset.isBurstPhoto, let count = burstCount, count > 1 {
                MediaBadge(type: .burst(count: count))
            }
        }
    }
}

#Preview("Live Photo Badge") {
    ZStack {
        Color.black
        MediaBadge(type: .live)
    }
}

#Preview("RAW Badge") {
    ZStack {
        Color.black
        MediaBadge(type: .raw)
    }
}

#Preview("Burst Badge") {
    ZStack {
        Color.black
        MediaBadge(type: .burst(count: 10))
    }
}
