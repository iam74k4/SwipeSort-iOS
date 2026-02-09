//
//  SettingsFeature.swift
//  Sift
//
//  Settings and configuration view
//

import SwiftUI
import UIKit

@available(iOS 18.0, *)
struct SettingsFeature: View {
    @Bindable var sortStore: SortResultStore
    
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    
    @State private var showResetConfirmation = false
    @State private var showAbout = false
    @State private var showTipJar = false

    @State private var showLinkError = false
    @State private var linkErrorMessage = ""

    private var supportEmail: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SiftSupportEmail") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private var feedbackMailURL: URL? {
        guard let email = supportEmail else { return nil }
        return URL(string: "mailto:\(email)?subject=Sift%20Feedback")
    }
    
    private var discordURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SiftDiscordURL") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private var appStoreReviewURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SiftAppStoreID") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let idPart = trimmed.lowercased().hasPrefix("id") ? trimmed : "id\(trimmed)"
        return URL(string: "https://apps.apple.com/app/\(idPart)?action=write-review")
    }

    private var privacyPolicyURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SiftPrivacyPolicyURL") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ThemeLayout.spacingItem) {
                    // Statistics Card
                    statisticsCard
                    
                    // Gesture Guide
                    gestureGuideCard
                    
                    // Settings
                    settingsCard
                    
                    // Data Management
                    dataCard
                    
                    // Support
                    supportCard
                    
                    // About
                    aboutCard
                }
                .padding(.horizontal, ThemeLayout.spacingItem)
                .padding(.bottom, ThemeLayout.spacingItem)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("Settings", comment: "Settings title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .confirmationDialog(
                NSLocalizedString("Reset Data", comment: "Reset data confirmation title"),
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("Reset", comment: "Reset button"), role: .destructive) {
                    sortStore.reset()
                    HapticFeedback.notification(.success)
                }
                Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Reset Data Message", comment: "Reset data confirmation message"))
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showTipJar) {
                TipJarView()
            }
            .alert(NSLocalizedString("Could Not Open", comment: "Could not open alert"), isPresented: $showLinkError) {
                Button(NSLocalizedString("OK", comment: "OK button")) {}
            } message: {
                Text(linkErrorMessage)
            }
        }
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        VStack(spacing: ThemeLayout.spacingMediumLarge) {
            HStack {
                Text(NSLocalizedString("Statistics", comment: "Statistics title"))
                    .font(.themeSectionLabel)
                    .foregroundStyle(Color.themeTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            HStack(spacing: ThemeLayout.paddingSmall) {
                StatisticItem(
                    count: sortStore.keepCount,
                    label: NSLocalizedString("Keep", comment: "Keep label"),
                    color: .keepColor,
                    icon: "checkmark.circle.fill"
                )
                
                StatisticItem(
                    count: sortStore.deleteCount,
                    label: NSLocalizedString("Deleted", comment: "Deleted label"),
                    color: .deleteColor,
                    icon: "trash.circle.fill"
                )
                
                StatisticItem(
                    count: sortStore.favoriteCount,
                    label: NSLocalizedString("Favorites", comment: "Favorites label"),
                    color: .favoriteColor,
                    icon: "heart.circle.fill"
                )
                
            }
            
            Divider()
                .background(Color.appBackgroundSecondary)
            
            HStack {
                Text(NSLocalizedString("Total", comment: "Total label"))
                    .font(.themeCaption)
                    .foregroundStyle(Color.themeSecondary)
                Spacer()
                Text("\(sortStore.totalSortedCount)")
                    .font(.themeDisplayValue)
                    .monospacedDigit()
                    .foregroundStyle(Color.themePrimary)
                Text(NSLocalizedString("items", comment: "Items unit"))
                    .font(.themeCaption)
                    .foregroundStyle(Color.themeSecondary)
            }
        }
        .padding(ThemeLayout.spacingItem)
        .glassCard()
    }
    
    // MARK: - Gesture Guide Card
    
    private var gestureGuideCard: some View {
        VStack(spacing: ThemeLayout.spacingMediumLarge) {
            HStack {
                Text(NSLocalizedString("Operations", comment: "Operations title"))
                    .font(.themeSectionLabel)
                    .foregroundStyle(Color.themeTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            VStack(spacing: ThemeLayout.paddingSmall) {
                GestureRow(
                    icon: "arrow.right",
                    direction: NSLocalizedString("Swipe Right", comment: "Swipe right"),
                    action: NSLocalizedString("Keep", comment: "Keep action"),
                    color: .keepColor
                )
                GestureRow(
                    icon: "arrow.left",
                    direction: NSLocalizedString("Swipe Left", comment: "Swipe left"),
                    action: NSLocalizedString("Add to Delete Queue", comment: "Add to delete queue"),
                    color: .deleteColor
                )
                GestureRow(
                    icon: "hand.tap.fill",
                    direction: NSLocalizedString("Double Tap", comment: "Double tap"),
                    action: NSLocalizedString("Favorite", comment: "Favorite action"),
                    color: .favoriteColor
                )
                GestureRow(
                    icon: "hand.point.up.left.fill",
                    direction: NSLocalizedString("Long Press", comment: "Long press"),
                    action: NSLocalizedString("Play (Video/Live Photo)", comment: "Play video/Live Photo"),
                    color: .iconMedia
                )
            }
        }
        .padding(ThemeLayout.spacingItem)
        .glassCard()
    }
    
    // MARK: - Settings Card
    
    private var settingsCard: some View {
        VStack(spacing: ThemeLayout.spacingMediumLarge) {
            HStack {
                Text(NSLocalizedString("Settings", comment: "Settings title"))
                    .font(.themeSectionLabel)
                    .foregroundStyle(Color.themeTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            Toggle(isOn: $hapticFeedbackEnabled) {
                HStack(spacing: ThemeLayout.spacingMedium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                            .fill(Color.iconHaptic.opacity(0.2))
                            .frame(width: ThemeLayout.buttonSizeSmall, height: ThemeLayout.buttonSizeSmall)
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.themeLabel)
                            .foregroundStyle(Color.iconHaptic)
                    }
                    
                    VStack(alignment: .leading, spacing: ThemeLayout.spacingTiny) {
                        Text(NSLocalizedString("Haptic Feedback", comment: "Haptic feedback"))
                            .font(.themeRowTitle)
                            .foregroundStyle(Color.themePrimary)
                        Text(NSLocalizedString("Vibrate on Swipe", comment: "Vibrate on swipe"))
                            .font(.themeCaptionSecondary)
                            .foregroundStyle(Color.themeSecondary)
                    }
                }
            }
            .tint(Color.iconHaptic)
            .accessibilityLabel(NSLocalizedString("Haptic Feedback", comment: "Haptic feedback"))
            .accessibilityHint(NSLocalizedString("Toggle to enable or disable vibration feedback", comment: "Haptic feedback hint"))
        }
        .padding(ThemeLayout.spacingItem)
        .glassCard()
    }
    
    // MARK: - Data Card
    
    private var dataCard: some View {
        VStack(spacing: ThemeLayout.spacingMediumLarge) {
            HStack {
                Text(NSLocalizedString("Data Management", comment: "Data management title"))
                    .font(.themeSectionLabel)
                    .foregroundStyle(Color.themeTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            Button {
                showResetConfirmation = true
            } label: {
                HStack(spacing: ThemeLayout.spacingMedium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                            .fill(Color.iconDanger.opacity(0.2))
                            .frame(width: ThemeLayout.buttonSizeSmall, height: ThemeLayout.buttonSizeSmall)
                        Image(systemName: "trash")
                            .font(.themeLabel)
                            .foregroundStyle(Color.iconDanger)
                    }
                    
                    VStack(alignment: .leading, spacing: ThemeLayout.spacingTiny) {
                        Text(NSLocalizedString("Reset All Data", comment: "Reset all data"))
                            .font(.themeRowTitle)
                            .foregroundStyle(Color.themePrimary)
                        Text(NSLocalizedString("Delete All Sorting Results", comment: "Delete all sorting results"))
                            .font(.themeCaptionSecondary)
                            .foregroundStyle(Color.themeSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.themeButtonSmall)
                        .foregroundStyle(Color.themeTertiary)
                }
            }
            .accessibilityLabel(NSLocalizedString("Reset All Data", comment: "Reset all data"))
            .accessibilityHint(NSLocalizedString("Delete all sorting results and start fresh", comment: "Reset data hint"))
        }
        .padding(ThemeLayout.spacingItem)
        .glassCard()
    }
    
    // MARK: - Support Card
    
    private var supportCard: some View {
        VStack(spacing: ThemeLayout.spacingMediumLarge) {
            HStack {
                Text(NSLocalizedString("Support", comment: "Support title"))
                    .font(.themeSectionLabel)
                    .foregroundStyle(Color.themeTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            VStack(spacing: 0) {
                // Contact / Feedback - Email
                Button {
                    if let url = feedbackMailURL {
                        UIApplication.shared.open(url)
                    } else {
                        linkErrorMessage = NSLocalizedString("Email Not Configured", comment: "Email not configured")
                        showLinkError = true
                    }
                } label: {
                    SettingsRow(
                        icon: "envelope",
                        iconColor: .iconFeedback,
                        title: NSLocalizedString("Send Feedback", comment: "Send feedback"),
                        showChevron: true,
                        isExternal: true
                    )
                }
                .accessibilityLabel(NSLocalizedString("Send Feedback", comment: "Send feedback"))
                .accessibilityHint(NSLocalizedString("Opens email to send feedback", comment: "Send feedback hint"))
                
                Divider()
                    .background(Color.appBackgroundSecondary)
                    .padding(.leading, ThemeLayout.spacingXLarge)
                
                // Contact / Feedback - Discord
                Button {
                    if let url = discordURL {
                        UIApplication.shared.open(url)
                    } else {
                        linkErrorMessage = NSLocalizedString("Discord Not Configured", comment: "Discord not configured")
                        showLinkError = true
                    }
                } label: {
                    SettingsRow(
                        icon: "message.fill",
                        iconColor: .iconCommunity,
                        title: NSLocalizedString("Discord Support", comment: "Discord support"),
                        showChevron: true,
                        isExternal: true
                    )
                }
                .accessibilityLabel(NSLocalizedString("Discord Support", comment: "Discord support"))
                .accessibilityHint(NSLocalizedString("Opens Discord for community support", comment: "Discord hint"))
                
                Divider()
                    .background(Color.appBackgroundSecondary)
                    .padding(.leading, ThemeLayout.spacingXLarge)
                
                // Rate on App Store
                Button {
                    if let url = appStoreReviewURL {
                        UIApplication.shared.open(url)
                    } else {
                        linkErrorMessage = NSLocalizedString("App Store ID Not Configured", comment: "App Store ID not configured")
                        showLinkError = true
                    }
                } label: {
                    SettingsRow(
                        icon: "star",
                        iconColor: .iconRating,
                        title: NSLocalizedString("Rate on App Store", comment: "Rate on App Store"),
                        showChevron: true,
                        isExternal: true
                    )
                }
                .accessibilityLabel(NSLocalizedString("Rate on App Store", comment: "Rate on App Store"))
                .accessibilityHint(NSLocalizedString("Opens App Store to leave a review", comment: "Rate hint"))
                
                Divider()
                    .background(Color.appBackgroundSecondary)
                    .padding(.leading, ThemeLayout.spacingXLarge)
                
                // Donate / Tip
                Button {
                    showTipJar = true
                } label: {
                    HStack(spacing: ThemeLayout.spacingMedium) {
                        ZStack {
                            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.pink, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: ThemeLayout.buttonSizeSmall, height: ThemeLayout.buttonSizeSmall)
                            Image(systemName: "heart.fill")
                                .font(.themeButtonSmall)
                                .foregroundStyle(Color.themePrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: ThemeLayout.spacingTiny) {
                            Text(NSLocalizedString("Developer Support", comment: "Developer support"))
                                .font(.themeRowTitle)
                                .foregroundStyle(Color.themePrimary)
                            Text(NSLocalizedString("Support with Tip", comment: "Support with tip"))
                                .font(.themeSectionLabel)
                                .foregroundStyle(Color.themeTertiary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.themeButtonSmall)
                            .foregroundStyle(Color.themeTertiary)
                    }
                    .padding(.vertical, ThemeLayout.spacingSmall)
                }
                .accessibilityLabel(NSLocalizedString("Developer Support", comment: "Developer support"))
                .accessibilityHint(NSLocalizedString("Opens tip jar to support the developer", comment: "Tip jar hint"))
            }
        }
        .padding(ThemeLayout.spacingItem)
        .glassCard()
    }
    
    // MARK: - About Card
    
    private var aboutCard: some View {
        VStack(spacing: ThemeLayout.spacingMediumLarge) {
            HStack {
                Text(NSLocalizedString("About", comment: "About title"))
                    .font(.themeSectionLabel)
                    .foregroundStyle(Color.themeTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            VStack(spacing: 0) {
                Button {
                    showAbout = true
                } label: {
                    SettingsRow(
                        icon: "info.circle",
                        iconColor: .iconInfo,
                        title: NSLocalizedString("About", comment: "About this app"),
                        showChevron: true
                    )
                }
                .accessibilityLabel(NSLocalizedString("About", comment: "About this app"))
                .accessibilityHint(NSLocalizedString("Shows app information and usage guide", comment: "About hint"))
                
                Divider()
                    .background(Color.appBackgroundSecondary)
                    .padding(.leading, ThemeLayout.spacingXXLarge)
                
                Button {
                    if let url = privacyPolicyURL {
                        UIApplication.shared.open(url)
                    } else {
                        linkErrorMessage = NSLocalizedString("Privacy Policy URL Not Configured", comment: "Privacy policy URL not configured")
                        showLinkError = true
                    }
                } label: {
                    SettingsRow(
                        icon: "hand.raised",
                        iconColor: .iconPrivacy,
                        title: NSLocalizedString("Privacy Policy", comment: "Privacy policy"),
                        showChevron: true,
                        isExternal: true
                    )
                }
                .accessibilityLabel(NSLocalizedString("Privacy Policy", comment: "Privacy policy"))
                .accessibilityHint(NSLocalizedString("Opens privacy policy in browser", comment: "Privacy policy hint"))
            }
        }
        .padding(ThemeLayout.spacingItem)
        .glassCard()
    }
}

// MARK: - Supporting Views

@available(iOS 18.0, *)
struct StatisticItem: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: ThemeLayout.paddingSmall) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: ThemeLayout.iconContainerSmall, height: ThemeLayout.iconContainerSmall)
                
                Image(systemName: icon)
                    .font(.themeBody)
                    .foregroundStyle(color)
            }
            
            Text("\(count)")
                .font(.themeDisplayValue)
                .monospacedDigit()
                .foregroundStyle(Color.themePrimary)
            
            Text(label)
                .font(.themeSectionLabel)
                .foregroundStyle(Color.themeTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(count)")
    }
}

@available(iOS 18.0, *)
struct GestureRow: View {
    let icon: String
    let direction: String
    let action: String
    let color: Color
    
    var body: some View {
        HStack(spacing: ThemeLayout.spacingMedium) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: ThemeLayout.buttonSizeSmall, height: ThemeLayout.buttonSizeSmall)
                
                Image(systemName: icon)
                    .font(.themeButtonSmall)
                    .foregroundStyle(color)
            }
            
            Text(direction)
                .font(.themeCaption)
                .foregroundStyle(Color.themeSecondary)
            
            Spacer()
            
            Text(action)
                .font(.themeCaption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.vertical, ThemeLayout.spacingXSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(direction): \(action)")
    }
}

@available(iOS 18.0, *)
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var showChevron: Bool = false
    var isExternal: Bool = false
    
    var body: some View {
        HStack(spacing: ThemeLayout.spacingMedium) {
            ZStack {
                RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: ThemeLayout.buttonSizeSmall, height: ThemeLayout.buttonSizeSmall)
                Image(systemName: icon)
                    .font(.themeButtonSmall)
                    .foregroundStyle(iconColor)
            }
            
            Text(title)
                .font(.themeRowTitle)
                .foregroundStyle(Color.themePrimary)
            
            Spacer()
            
            if showChevron {
                Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                    .font(.themeButtonSmall)
                    .foregroundStyle(Color.themeTertiary)
            }
        }
        .padding(.vertical, ThemeLayout.spacingSmall)
    }
}

// MARK: - About View

@available(iOS 18.0, *)
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ThemeLayout.spacingSection) {
                    // App Icon
                    VStack(spacing: ThemeLayout.spacingMediumLarge) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: ThemeLayout.iconContainerLarge, height: ThemeLayout.iconContainerLarge)
                        
                        Image(systemName: "hand.draw.fill")
                            .font(.themeTitleLarge)
                            .foregroundStyle(Color.themePrimary)
                    }
                    .shadow(color: .purple.opacity(0.5), radius: ThemeLayout.shadowRadiusLarge, x: 0, y: ThemeLayout.shadowYLarge)
                        
                        VStack(spacing: ThemeLayout.spacingXSmall) {
                            Text("Sift")
                                .font(.themeTitleLarge)
                            
                            Text(String(format: NSLocalizedString("Version %@", comment: "Version"), Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                                .font(.themeCaption)
                                .foregroundStyle(Color.themeTertiary)
                        }
                    }
                    .padding(.top, ThemeLayout.paddingLarge)
                    
                    // Description
                    VStack(alignment: .leading, spacing: ThemeLayout.spacingItem) {
                        VStack(alignment: .leading, spacing: ThemeLayout.spacingSmall) {
                            Text(NSLocalizedString("About", comment: "About this app"))
                                .font(.themeRowTitle.weight(.semibold))
                            
                            Text(NSLocalizedString("About Description", comment: "About description"))
                                .font(.themeButtonSmall)
                                .foregroundStyle(Color.themeTertiary)
                                .lineSpacing(ThemeLayout.lineSpacingDefault)
                        }
                        
                        VStack(alignment: .leading, spacing: ThemeLayout.spacingMediumLarge) {
                            Text(NSLocalizedString("Operations", comment: "Operations title"))
                                .font(.themeRowTitle.weight(.semibold))
                            
                            VStack(spacing: ThemeLayout.paddingSmall) {
                                InstructionRow(
                                    icon: "arrow.right.circle.fill",
                                    color: .keepColor,
                                    text: NSLocalizedString("Swipe Right", comment: "Swipe right"),
                                    description: NSLocalizedString("Keep", comment: "Keep action")
                                )
                                InstructionRow(
                                    icon: "arrow.left.circle.fill",
                                    color: .deleteColor,
                                    text: NSLocalizedString("Swipe Left", comment: "Swipe left"),
                                    description: NSLocalizedString("Add to Delete Queue", comment: "Add to delete queue")
                                )
                                InstructionRow(
                                    icon: "heart.circle.fill",
                                    color: .favoriteColor,
                                    text: NSLocalizedString("Double Tap", comment: "Double tap"),
                                    description: NSLocalizedString("Favorite", comment: "Favorite action")
                                )
                                InstructionRow(
                                    icon: "hand.point.up.left.fill",
                                    color: .iconMedia,
                                    text: NSLocalizedString("Long Press", comment: "Long press"),
                                    description: NSLocalizedString("Play (Video/Live Photo)", comment: "Play video/Live Photo")
                                )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: ThemeLayout.spacingSmall) {
                            Text(NSLocalizedString("About Delete", comment: "About delete"))
                                .font(.themeRowTitle.weight(.semibold))
                            
                            Text(NSLocalizedString("About Delete Description", comment: "About delete description"))
                                .font(.themeButtonSmall)
                                .foregroundStyle(Color.themeTertiary)
                                .lineSpacing(ThemeLayout.lineSpacingDefault)
                        }
                        
                        VStack(alignment: .leading, spacing: ThemeLayout.spacingSmall) {
                            Text(NSLocalizedString("Other Features", comment: "Other features"))
                                .font(.themeRowTitle.weight(.semibold))
                            
                            VStack(alignment: .leading, spacing: ThemeLayout.spacingCompact) {
                                Text(NSLocalizedString("• Filter: Filter by photos, videos, Live Photos, etc.", comment: "Filter feature"))
                                    .font(.themeButtonSmall)
                                    .foregroundStyle(Color.themeTertiary)
                                Text(NSLocalizedString("• Undo: Cancel the last action", comment: "Undo feature"))
                                    .font(.themeButtonSmall)
                                    .foregroundStyle(Color.themeTertiary)
                                Text(NSLocalizedString("• Date Display: Show photo creation date", comment: "Date display feature"))
                                    .font(.themeButtonSmall)
                                    .foregroundStyle(Color.themeTertiary)
                            }
                                .lineSpacing(ThemeLayout.lineSpacingDefault)
                        }
                    }
                    .padding(.horizontal, ThemeLayout.spacingItem)
                    
                    Spacer(minLength: ThemeLayout.minSpacerHeight)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("About", comment: "About this app"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Close", comment: "Close button")) { dismiss() }
                }
            }
        }
    }
}

@available(iOS 18.0, *)
struct InstructionRow: View {
    let icon: String
    let color: Color
    let text: String
    let description: String
    
    var body: some View {
        HStack(spacing: ThemeLayout.spacingMediumLarge) {
            Image(systemName: icon)
                .font(.themeTitle)
                .foregroundStyle(color)
                .frame(width: ThemeLayout.buttonSizeSmall)
            
            VStack(alignment: .leading, spacing: ThemeLayout.spacingTiny) {
                Text(text)
                    .font(.themeButtonSmall)
                Text(description)
                    .font(.themeCaptionSecondary)
                    .foregroundStyle(Color.themeTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, ThemeLayout.spacingXSmall)
    }
}
