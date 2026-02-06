//
//  AppTheme.swift
//  Sift
//
//  App-wide theme definitions
//

import SwiftUI

// MARK: - Layout Tokens

enum ThemeLayout {
    // MARK: - Corner Radius (Standard iOS style)
    /// Corner radius for cards and sheets
    static let cornerRadiusCard: CGFloat = 16
    static let cornerRadiusButton: CGFloat = 12
    /// Corner radius for smaller chips and badges
    static let cornerRadiusChip: CGFloat = 8
    /// Corner radius for floating bars (Concentric: 16pt bar - 4pt padding = 12pt children)
    static let cornerRadiusFloatingBar: CGFloat = 16
    
    /// Opacity for glass-style stroke borders
    static let glassEdgeOpacity: Double = 0.15
    
    // MARK: - Spacing (8-point grid system)
    static let spacingTiny: CGFloat = 1
    static let spacingXSmall: CGFloat = 2
    static let spacingXXSmall: CGFloat = 3
    static let spacingCompact: CGFloat = 4
    static let spacingSmall: CGFloat = 6
    static let paddingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 10
    static let spacingMediumLarge: CGFloat = 12
    /// Spacing for list/item padding
    static let spacingItem: CGFloat = 16
    static let spacingLarge: CGFloat = 20
    /// Large section padding
    static let paddingLarge: CGFloat = 24
    static let spacingSection: CGFloat = 32
    static let spacingXLarge: CGFloat = 40
    static let spacingXXLarge: CGFloat = 48
    /// Floating bar margin from screen edge (edge-to-edge Liquid Glass style)
    static let paddingFloating: CGFloat = 8
    
    // MARK: - Opacity
    static let opacityXLight: Double = 0.05
    static let opacityLight: Double = 0.08
    static let opacityMedium: Double = 0.12
    static let opacityStrong: Double = 0.2
    static let opacityHeavy: Double = 0.5
    static let opacityXHeavy: Double = 0.7
    
    // MARK: - Shadow
    /// Subtle shadow for elevated cards (modern, less heavy)
    static let shadowRadiusCard: CGFloat = 8
    static let shadowOpacityCard: Double = 0.15
    static let shadowYCard: CGFloat = 4
    /// Small shadow for pills and buttons
    static let shadowRadiusSmall: CGFloat = 4
    static let shadowOpacitySmall: Double = 0.4
    static let shadowYSmall: CGFloat = 2
    
    // MARK: - Fixed Sizes
    static let buttonSizeSmall: CGFloat = 32
    static let buttonSizeMedium: CGFloat = 44
    static let iconContainerSmall: CGFloat = 40
    static let iconContainerMedium: CGFloat = 64
    static let iconContainerLarge: CGFloat = 80
    static let iconContainerXLarge: CGFloat = 160
    static let dividerHeight: CGFloat = 16
    static let dividerHeightLarge: CGFloat = 24
    static let videoTimeLabelWidth: CGFloat = 45
    static let toastBottomPadding: CGFloat = 100
    static let lineWidthThin: CGFloat = 1
    static let lineWidthMedium: CGFloat = 4
    static let compactPillWidth: CGFloat = 80
    static let emojiContainerSize: CGFloat = 48
    static let loadingPlaceholderHeight: CGFloat = 200
    static let minSpacerHeight: CGFloat = 24
    
    // MARK: - Shadow Presets
    static let shadowRadiusLarge: CGFloat = 16
    static let shadowYLarge: CGFloat = 8
    /// Subtle secondary shadow
    static let shadowOpacitySubtle: Double = 0.08
    static let shadowRadiusTiny: CGFloat = 2
    static let shadowYTiny: CGFloat = 1
    
    // MARK: - Scale
    static let scaleLoading: CGFloat = 1.2
    
    // MARK: - Text
    static let lineSpacingDefault: CGFloat = 4
}

// MARK: - Colors

extension Color {
    // Category colors
    static let keepColor = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let deleteColor = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let favoriteColor = Color(red: 1.0, green: 0.75, blue: 0.0)
    
    // Background
    static let appBackground = Color(red: 0.06, green: 0.06, blue: 0.08)
    /// Slightly lighter background for secondary surfaces (e.g. bars, overlays)
    static let appBackgroundSecondary = Color(red: 0.09, green: 0.09, blue: 0.11)
    
    // Semantic (for text and surfaces)
    static let themePrimary = Color.white
    static let themeSecondary = Color.white.opacity(0.7)
    static let themeTertiary = Color.white.opacity(0.5)
    
    // Icon colors (for settings and UI elements)
    static let iconHaptic = Color.purple
    static let iconDanger = Color.red
    static let iconFeedback = Color.cyan
    static let iconCommunity = Color.indigo
    static let iconRating = Color.yellow
    static let iconInfo = Color.blue       // For info/about sections
    static let iconPrivacy = Color.green
    static let iconMedia = Color.cyan      // For media playback indicators
}

// MARK: - Typography

extension Font {
    /// Title / large heading (Dynamic Type)
    static let themeTitle = Font.system(size: 22, weight: .semibold)
    static let themeTitleLarge = Font.system(size: 28, weight: .bold)
    /// Body and list content
    static let themeBody = Font.body
    static let themeBodyMedium = Font.body.weight(.medium)
    /// Section headers (e.g. "STATISTICS", "SETTINGS" uppercase)
    static let themeSectionLabel = Font.system(size: 11, weight: .medium)
    /// Row title / list primary (e.g. toggle titles)
    static let themeRowTitle = Font.system(size: 16, weight: .medium)
    /// Display value (e.g. big numbers in stats)
    static let themeDisplayValue = Font.system(size: 20, weight: .semibold)
    /// Caption and secondary labels
    static let themeCaption = Font.system(size: 13, weight: .medium)
    static let themeCaptionSecondary = Font.system(size: 12, weight: .regular)
    /// Small label (chips, secondary row text)
    static let themeLabel = Font.system(size: 12, weight: .medium)
    /// Buttons and pills
    static let themeButton = Font.system(size: 17, weight: .semibold)
    static let themeButtonSmall = Font.system(size: 14, weight: .semibold)
    /// Badge / pill numbers
    static let themeBadge = Font.system(size: 12, weight: .bold, design: .rounded)
    
    // Large display fonts (for stamps, overlays, empty states)
    static let themeDisplayXLarge = Font.system(size: 48, weight: .thin)
    static let themeDisplayXXLarge = Font.system(size: 60, weight: .thin)
    static let themeDisplayHuge = Font.system(size: 72, weight: .thin)
    static let themeIconLarge = Font.system(size: 32)
    static let themeIconXLarge = Font.system(size: 64)
    static let themeIconHuge = Font.system(size: 80)
    static let themeStamp = Font.system(size: 36, weight: .black, design: .rounded)
}

// MARK: - Material (ShapeStyle)

extension ShapeStyle where Self == Material {
    /// Ultra-thin material for bars and overlays (modern glass)
    @available(iOS 18.0, *)
    static var themeBarMaterial: Material { .ultraThinMaterial }
    /// Slightly stronger material for cards
    @available(iOS 18.0, *)
    static var themeCardMaterial: Material { .regularMaterial }
}

// MARK: - View Modifiers

extension View {
    /// Apply glass card style for settings and content cards (material-based, modern)
    @available(iOS 18.0, *)
    func glassCard(cornerRadius: CGFloat = ThemeLayout.cornerRadiusCard) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.themeCardMaterial)
            }
    }
}

// MARK: - Animations

extension Animation {
    static let photoSlide = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let overlayFade = Animation.easeOut(duration: 0.15)
    static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.6)
}

// MARK: - UserDefaults Keys

enum UserDefaultsKey {
    static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
}

// MARK: - Haptic Feedback

/// Singleton haptic feedback manager that reuses UIFeedbackGenerator instances
/// for better performance and battery efficiency.
@MainActor
final class HapticFeedback {
    static let shared = HapticFeedback()
    
    // Reusable feedback generators (recommended by Apple)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {
        // Pre-warm the most commonly used generators
        impactMedium.prepare()
        impactLight.prepare()
    }
    
    /// Check if haptic feedback is enabled from user settings
    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: UserDefaultsKey.hapticFeedbackEnabled) as? Bool ?? true
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        case .soft:
            impactSoft.impactOccurred()
        case .rigid:
            impactRigid.impactOccurred()
        @unknown default:
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(type)
    }
    
    func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }
    
    // MARK: - Static Convenience Methods (backward compatibility)
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        shared.impact(style)
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        shared.notification(type)
    }
    
    static func selection() {
        shared.selection()
    }
}

// MARK: - Constants

enum SwipeThreshold {
    static let horizontal: CGFloat = 120
    static let vertical: CGFloat = 100
    static let detectionStart: CGFloat = 50
}

enum CardAnimation {
    /// Scale divisor for card shrink during drag
    static let scaleDivisor: CGFloat = 3000
    /// Rotation divisor for card tilt during drag
    static let rotationDivisor: Double = 25
    /// Horizontal offset for swipe-out animation
    static let swipeOutOffset: CGFloat = 500
    /// Vertical offset for swipe-out animation
    static let swipeOutVerticalOffset: CGFloat = 50
    /// Scale for pressed state
    static let pressedScale: CGFloat = 0.95
    /// Scale for card during drag
    static let dragScale: CGFloat = 0.97
    /// Scale for enlarged elements (e.g., favorite animation)
    static let enlargedScale: CGFloat = 1.2
    /// Stamp rotation angle (degrees)
    static let stampRotation: Double = 15
    /// Progress threshold for showing stamp
    static let stampThreshold: Double = 0.3
    /// Gradient end radius for glow effects
    static let glowEndRadius: CGFloat = 400
    /// Card dimension offset for layout
    static let cardDimensionOffset: CGFloat = 8
    /// Next card offset for stacked effect
    static let nextCardOffset: CGFloat = 6
    /// Undo animation horizontal offset
    static let undoAnimationOffset: CGFloat = -400
    /// Stamp position (x ratio from center)
    static let stampPositionX: CGFloat = 0.35
    /// Stamp position (y ratio from center)
    static let stampPositionY: CGFloat = 0.18
    /// Stamp opacity (visible)
    static let stampOpacity: Double = 0.8
    /// Stamp scale base
    static let stampScaleBase: Double = 0.8
    /// Stamp scale max addition
    static let stampScaleMax: Double = 0.2
    /// Stamp scale (visible)
    static let stampScale: Double = 1.2
}

enum CacheConstants {
    /// Number of assets to cache ahead
    static let cacheAheadCount: Int = 5
}

enum TimingConstants {
    /// Delay before showing swipe hint (milliseconds)
    static let swipeHintDelay: Int = 500
    /// Toast display duration (milliseconds)
    static let toastDuration: Int = 1500
    /// Animation durations (seconds)
    static let durationInstant: Double = 0.12
    static let durationFast: Double = 0.15
    static let durationNormal: Double = 0.2
    static let durationMedium: Double = 0.25
    static let durationSlow: Double = 0.3
    static let durationVerySlow: Double = 0.6
    /// Sleep durations (milliseconds)
    static let sleepShort: Int = 100
    static let sleepNormal: Int = 250
    static let sleepMedium: Int = 300
    static let sleepLong: Int = 600
}

enum ImageConstants {
    /// Maximum image size for loading (pixels)
    /// Used to prevent excessive memory usage while maintaining quality
    static let maxImageSize: CGFloat = 2400
}
