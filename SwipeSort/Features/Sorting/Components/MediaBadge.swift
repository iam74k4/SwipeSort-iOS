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
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))
            if let text = text {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(Color.black.opacity(0.5))
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
