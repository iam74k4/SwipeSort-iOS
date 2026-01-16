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
    
    private var glowOpacity: Double {
        // Up swipe (skip) needs stronger glow for visibility
        if direction == .up {
            return min(progress * 0.8, 0.6)
        }
        return min(progress * 0.6, 0.4)
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
        .animation(.easeOut(duration: 0.12), value: direction)
        .animation(.easeOut(duration: 0.12), value: progress)
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
                Spacer()
            }
            
        case .up:
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .skipColor.opacity(glowOpacity * 1.5), location: 0),
                                .init(color: .skipColor.opacity(glowOpacity * 0.8), location: 0.3),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: geometry.size.height * 0.4)
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
            
        case .up:
            iconBubble(
                icon: "arrow.up.circle.fill",
                color: .skipColor,
                position: CGPoint(x: geometry.size.width / 2, y: 60)
            )
            
        case .none:
            EmptyView()
        }
    }
    
    private func iconBubble(icon: String, color: Color, position: CGPoint) -> some View {
        ZStack {
            // Glow (stronger for up swipe)
            let glowSize: CGFloat = direction == .up ? 100 : 80
            let glowIntensity: Double = direction == .up ? 0.6 : 0.4
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
            
            // Icon (larger for up swipe)
            let iconSize: CGFloat = direction == .up ? 28 : 24
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
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

#Preview("Skip") {
    ZStack {
        Color.appBackground
        SwipeOverlay(direction: .up, progress: 0.8)
    }
    .ignoresSafeArea()
}
