//
//  AppTheme.swift
//  SwipeSort
//
//  App-wide theme definitions
//

import SwiftUI

// MARK: - Colors

extension Color {
    // Category colors
    static let keepColor = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let deleteColor = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let favoriteColor = Color(red: 1.0, green: 0.75, blue: 0.0)
    static let unsortedColor = Color.gray
    
    // Gradient colors
    static let keepGradientStart = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let keepGradientEnd = Color(red: 0.1, green: 0.6, blue: 0.3)
    
    static let deleteGradientStart = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let deleteGradientEnd = Color(red: 0.8, green: 0.1, blue: 0.2)
    
    static let favoriteGradientStart = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let favoriteGradientEnd = Color(red: 1.0, green: 0.6, blue: 0.0)
    
    // Background
    static let appBackground = Color(red: 0.06, green: 0.06, blue: 0.08)
}

// MARK: - Gradients

extension LinearGradient {
    static let keepGradient = LinearGradient(
        colors: [.keepGradientStart, .keepGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let deleteGradient = LinearGradient(
        colors: [.deleteGradientStart, .deleteGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let favoriteGradient = LinearGradient(
        colors: [.favoriteGradientStart, .favoriteGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers

extension View {
    /// Apply Liquid Glass effect background (iOS 26+)
    @available(iOS 26.0, *)
    func liquidGlass(cornerRadius: CGFloat = 20) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .glassEffect()
    }
    
    /// Apply glass card style for settings and content cards
    @available(iOS 26.0, *)
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .white.opacity(0.05), radius: 0, x: 0, y: 1)
            }
            .glassEffect()
    }
    
    /// Apply glass pill style for buttons and badges
    @available(iOS 26.0, *)
    func glassPill() -> some View {
        self
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            .glassEffect()
    }
    
    /// Floating shadow for elevated elements
    func floatingShadow(color: Color = .black) -> some View {
        self
            .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 6)
            .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Animations

extension Animation {
    static let photoSlide = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let overlayFade = Animation.easeOut(duration: 0.15)
    static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.6)
}

// MARK: - Haptic Feedback

@MainActor
enum HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Constants

enum SwipeThreshold {
    static let horizontal: CGFloat = 120
    static let vertical: CGFloat = 120
    static let detectionStart: CGFloat = 50
}
