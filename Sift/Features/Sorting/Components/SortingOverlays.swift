//
//  SortingOverlays.swift
//  Sift
//
//  Overlay views for the sorting feature (stamps, hints)
//

import SwiftUI

// MARK: - Stamp View

struct StampView: View {
    let text: String
    let color: Color
    let rotation: Double
    
    var body: some View {
        Text(text)
            .font(.themeStamp)
            .foregroundStyle(color)
            .shadow(color: color.opacity(ThemeLayout.opacityXHeavy), radius: 12, x: 0, y: 0)  // Stronger glow for better visibility
            .shadow(color: Color.cardShadow, radius: 6, x: 0, y: 3)  // Stronger outline
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Swipe Hint Overlay

struct SwipeHintOverlay: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(ThemeLayout.opacityXHeavy)  // Dimming overlay — intentionally black
                .ignoresSafeArea()
            
            VStack(spacing: ThemeLayout.spacingSection) {
                // Swipe arrows and labels
                HStack(spacing: ThemeLayout.iconContainerLarge) {
                    // Left - Delete
                    VStack(spacing: ThemeLayout.paddingSmall) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.themeDisplayXLarge)
                            .foregroundStyle(Color.deleteColor)
                        Text(NSLocalizedString("Delete", comment: "Delete button"))
                            .font(.themeRowTitle.weight(.bold))
                            .foregroundStyle(Color.deleteColor)
                    }
                    
                    // Right - Keep
                    VStack(spacing: ThemeLayout.paddingSmall) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.themeDisplayXLarge)
                            .foregroundStyle(Color.keepColor)
                        Text(NSLocalizedString("Save", comment: "Save button"))
                            .font(.themeRowTitle.weight(.bold))
                            .foregroundStyle(Color.keepColor)
                    }
                }
                
                // Double tap hint
                VStack(spacing: ThemeLayout.spacingSmall) {
                    Image(systemName: "heart.fill")
                        .font(.themeTitle)
                        .foregroundStyle(Color.favoriteColor)
                    Text(NSLocalizedString("Double Tap = Favorite", comment: "Double tap hint"))
                        .font(.themeCaption)
                        .foregroundStyle(Color.themeSecondary)
                }
                .padding(.top, ThemeLayout.paddingSmall)
                
                // Dismiss hint
                Text(NSLocalizedString("Tap to Start", comment: "Tap to start message"))
                    .font(.themeCaption)
                    .foregroundStyle(Color.themeTertiary)
                    .padding(.top, ThemeLayout.paddingLarge)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss()
        }
        .transition(.opacity)
    }
}
