//
//  SwipeOverlay.swift
//  SwipeSort
//
//  Elegant edge glow for swipe direction feedback
//

import SwiftUI

struct SwipeOverlay: View {
    let direction: SwipeDirection
    let progress: Double
    
    /// Slightly softer glow for modern look
    private var glowOpacity: Double {
        min(progress * 0.5, 0.35)
    }
    
    private var iconOpacity: Double {
        min(max(progress - 0.2, 0) * 1.5, 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Edge glow
                edgeGlow(in: geometry)
                
                // Direction icon
                directionIcon(in: geometry)
            }
        }
        .animation(.easeOut(duration: TimingConstants.durationInstant), value: direction)
        .animation(.easeOut(duration: TimingConstants.durationInstant), value: progress)
    }
    
    // MARK: - Edge Glow
    
    @ViewBuilder
    private func edgeGlow(in geometry: GeometryProxy) -> some View {
        switch direction {
        case .right:
            HStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .keepColor.opacity(glowOpacity), location: 0),
                                .init(color: .keepColor.opacity(glowOpacity * 0.5), location: 0.3),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: geometry.size.width * 0.4)
                    .blur(radius: 1)
            }
            
        case .left:
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .deleteColor.opacity(glowOpacity), location: 0),
                                .init(color: .deleteColor.opacity(glowOpacity * 0.5), location: 0.3),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * 0.4)
                    .blur(radius: 1)
                Spacer()
            }
            
        case .none:
            EmptyView()
        }
    }
    
    // MARK: - Direction Icon
    
    @ViewBuilder
    private func directionIcon(in geometry: GeometryProxy) -> some View {
        switch direction {
        case .right:
            iconBubble(
                icon: "checkmark.circle.fill",
                color: .keepColor,
                position: CGPoint(x: geometry.size.width - 50, y: geometry.size.height / 2)
            )
            
        case .left:
            iconBubble(
                icon: "trash.circle.fill",
                color: .deleteColor,
                position: CGPoint(x: 50, y: geometry.size.height / 2)
            )
            
        case .none:
            EmptyView()
        }
    }
    
    private func iconBubble(icon: String, color: Color, position: CGPoint) -> some View {
        ZStack {
            // Glow (slightly softer for modern look)
            let glowSize: CGFloat = 80
            let glowIntensity: Double = 0.32
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(glowIntensity), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: glowSize, height: glowSize)
            
            // Icon
            let iconSize: CGFloat = 24
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
                .scaleEffect(0.8 + min(progress, 0.3))
        }
        .opacity(iconOpacity)
        .position(position)
    }
}

#Preview("Keep") {
    ZStack {
        Color.appBackground
        SwipeOverlay(direction: .right, progress: 0.8)
    }
    .ignoresSafeArea()
}

#Preview("Delete") {
    ZStack {
        Color.appBackground
        SwipeOverlay(direction: .left, progress: 0.8)
    }
    .ignoresSafeArea()
}

