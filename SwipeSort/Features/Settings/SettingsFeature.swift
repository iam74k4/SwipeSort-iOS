//
//  SettingsFeature.swift
//  SwipeSort
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

    private var supportEmail: String {
        (Bundle.main.object(forInfoDictionaryKey: "SwipeSortSupportEmail") as? String)
            ?? "iam74k4@gmail.com"
    }

    private var feedbackMailURL: URL? {
        URL(string: "mailto:\(supportEmail)?subject=SwipeSort%20Feedback")
    }
    
    private var discordURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SwipeSortDiscordURL") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private var appStoreReviewURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SwipeSortAppStoreID") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let idPart = trimmed.lowercased().hasPrefix("id") ? trimmed : "id\(trimmed)"
        return URL(string: "https://apps.apple.com/app/\(idPart)?action=write-review")
    }

    private var privacyPolicyURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SwipeSortPrivacyPolicyURL") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        VStack(spacing: 20) {
            HStack {
                Text(NSLocalizedString("Statistics", comment: "Statistics title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            HStack(spacing: 12) {
                StatisticItem(
                    count: sortStore.keepCount,
                    label: "Keep",
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
                
                StatisticItem(
                    count: sortStore.unsortedCount,
                    label: NSLocalizedString("Skip", comment: "Skip label"),
                    color: .skipColor,
                    icon: "arrow.up.circle.fill"
                )
            }
            
            Divider()
                .background(.white.opacity(0.1))
            
            HStack {
                Text(NSLocalizedString("Total", comment: "Total label"))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(sortStore.totalSortedCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(NSLocalizedString("items", comment: "Items unit"))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(20)
        .glassCard()
    }
    
    // MARK: - Gesture Guide Card
    
    private var gestureGuideCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(NSLocalizedString("Operations", comment: "Operations title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            VStack(spacing: 12) {
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
                    icon: "arrow.up",
                    direction: NSLocalizedString("Swipe Up", comment: "Swipe up"),
                    action: NSLocalizedString("Skip", comment: "Skip action"),
                    color: .skipColor
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
                    color: .blue
                )
            }
        }
        .padding(20)
        .glassCard()
    }
    
    // MARK: - Settings Card
    
    private var settingsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(NSLocalizedString("Settings", comment: "Settings title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            Toggle(isOn: $hapticFeedbackEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.purple.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 16))
                            .foregroundStyle(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Haptic Feedback", comment: "Haptic feedback"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Text(NSLocalizedString("Vibrate on Swipe", comment: "Vibrate on swipe"))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .tint(.purple)
        }
        .padding(20)
        .glassCard()
    }
    
    // MARK: - Data Card
    
    private var dataCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(NSLocalizedString("Data Management", comment: "Data management title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            Button {
                showResetConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.red.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Reset All Data", comment: "Reset all data"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Text(NSLocalizedString("Delete All Sorting Results", comment: "Delete all sorting results"))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(20)
        .glassCard()
    }
    
    // MARK: - Support Card
    
    private var supportCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(NSLocalizedString("Support", comment: "Support title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
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
                        iconColor: .cyan,
                        title: NSLocalizedString("Send Feedback", comment: "Send feedback"),
                        showChevron: true,
                        isExternal: true
                    )
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.leading, 48)
                
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
                        iconColor: .indigo,
                        title: NSLocalizedString("Discord Support", comment: "Discord support"),
                        showChevron: true,
                        isExternal: true
                    )
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.leading, 48)
                
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
                        iconColor: .yellow,
                        title: NSLocalizedString("Rate on App Store", comment: "Rate on App Store"),
                        showChevron: true,
                        isExternal: true
                    )
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.leading, 48)
                
                // Donate / Tip
                Button {
                    showTipJar = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.pink, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Developer Support", comment: "Developer support"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                            Text(NSLocalizedString("Support with Tip", comment: "Support with tip"))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .glassCard()
    }
    
    // MARK: - About Card
    
    private var aboutCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(NSLocalizedString("About", comment: "About title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
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
                        iconColor: .blue,
                        title: NSLocalizedString("About", comment: "About this app"),
                        showChevron: true
                    )
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.leading, 48)
                
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
                        iconColor: .green,
                        title: NSLocalizedString("Privacy Policy", comment: "Privacy policy"),
                        showChevron: true,
                        isExternal: true
                    )
                }
            }
        }
        .padding(20)
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
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
            }
            
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 18.0, *)
struct GestureRow: View {
    let icon: String
    let direction: String
    let action: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            Text(direction)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
            
            Text(action)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            if showChevron {
                Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - About View

@available(iOS 18.0, *)
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    // App Icon
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 4) {
                            Text("SwipeSort")
                                .font(.system(size: 28, weight: .bold))
                            
                            Text(String(format: NSLocalizedString("Version %@", comment: "Version"), "1.0"))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("About", comment: "About this app"))
                                .font(.system(size: 17, weight: .semibold))
                            
                            Text(NSLocalizedString("About Description", comment: "About description"))
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text(NSLocalizedString("Operations", comment: "Operations title"))
                                .font(.system(size: 17, weight: .semibold))
                            
                            VStack(spacing: 12) {
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
                                    icon: "arrow.up.circle.fill",
                                    color: .skipColor,
                                    text: NSLocalizedString("Swipe Up", comment: "Swipe up"),
                                    description: NSLocalizedString("Skip", comment: "Skip action")
                                )
                                InstructionRow(
                                    icon: "heart.circle.fill",
                                    color: .favoriteColor,
                                    text: NSLocalizedString("Double Tap", comment: "Double tap"),
                                    description: NSLocalizedString("Favorite", comment: "Favorite action")
                                )
                                InstructionRow(
                                    icon: "hand.point.up.left.fill",
                                    color: .blue,
                                    text: NSLocalizedString("Long Press", comment: "Long press"),
                                    description: NSLocalizedString("Play (Video/Live Photo)", comment: "Play video/Live Photo")
                                )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("About Delete", comment: "About delete"))
                                .font(.system(size: 17, weight: .semibold))
                            
                            Text(NSLocalizedString("About Delete Description", comment: "About delete description"))
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("Other Features", comment: "Other features"))
                                .font(.system(size: 17, weight: .semibold))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(NSLocalizedString("• Filter: Filter by photos, videos, Live Photos, etc.", comment: "Filter feature"))
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                Text(NSLocalizedString("• Undo: Cancel the last action", comment: "Undo feature"))
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                Text(NSLocalizedString("• Date Display: Show photo creation date", comment: "Date display feature"))
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                                .lineSpacing(4)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
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
        .preferredColorScheme(.dark)
    }
}

@available(iOS 18.0, *)
struct InstructionRow: View {
    let icon: String
    let color: Color
    let text: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 15, weight: .medium))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
