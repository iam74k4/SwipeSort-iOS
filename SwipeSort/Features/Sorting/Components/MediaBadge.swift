//
//  MediaBadge.swift
//  SwipeSort
//
//  Media type badge component
//

import SwiftUI

enum MediaBadgeType {
    case live
    case raw
    case burst(count: Int)
}

@available(iOS 18.0, *)
struct MediaBadge: View {
    let type: MediaBadgeType
    
    var body: some View {
        HStack(spacing: ThemeLayout.spacingCompact) {
            Image(systemName: iconName)
                .font(.themeBadge)
            if let text = text {
                Text(text)
                    .font(.themeBadge)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, ThemeLayout.paddingSmall)
        .padding(.vertical, ThemeLayout.paddingSmall / 2)
        .background {
            Capsule()
                .fill(Color.black.opacity(ThemeLayout.opacityHeavy))
        }
        .accessibilityLabel(accessibilityText)
    }
    
    private var accessibilityText: String {
        switch type {
        case .live:
            return NSLocalizedString("Live Photo", comment: "Live Photo badge")
        case .raw:
            return NSLocalizedString("RAW Photo", comment: "RAW Photo badge")
        case .burst(let count):
            return String(format: NSLocalizedString("Burst with %d photos", comment: "Burst badge"), count)
        }
    }
    
    private var iconName: String {
        switch type {
        case .live:
            return "livephoto"
        case .raw:
            return "camera.filters"
        case .burst:
            return "square.stack.3d.up"
        }
    }
    
    private var text: String? {
        switch type {
        case .live, .raw:
            return nil
        case .burst(let count):
            return "\(count)"
        }
    }
}
