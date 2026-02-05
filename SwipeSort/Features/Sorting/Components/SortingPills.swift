//
//  SortingPills.swift
//  SwipeSort
//
//  Supporting views for the sorting feature (pills, chips, overlays)
//

import SwiftUI

// MARK: - Stat Pills

@available(iOS 18.0, *)
struct StatPill: View {
    let count: Int
    let color: Color
    let icon: String
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: ThemeLayout.spacingXXSmall) {
            Image(systemName: icon)
                .font(.themeButtonSmall)
            Text("\(count)")
                .font(.themeButtonSmall)
                .monospacedDigit()
                .lineLimit(1)
        }
        .fixedSize()
        .foregroundStyle(isSelected ? .white : color)
        .padding(.horizontal, ThemeLayout.spacingMedium)
        .padding(.vertical, ThemeLayout.spacingSmall)
        .background {
            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                .fill(isSelected ? color : Color.black.opacity(ThemeLayout.opacityHeavy))
        }
        .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
    }
}

@available(iOS 18.0, *)
struct ProgressPill: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: ThemeLayout.spacingXXSmall) {
            Text("\(current)")
                .font(.themeButtonSmall)
                .foregroundStyle(Color.themePrimary)
                .lineLimit(1)
            Text("/")
                .font(.themeButtonSmall)
                .foregroundStyle(Color.themeTertiary)
            Text("\(total)")
                .font(.themeButtonSmall)
                .foregroundStyle(Color.themeSecondary)
                .lineLimit(1)
        }
        .fixedSize()
        .monospacedDigit()
        .padding(.horizontal, ThemeLayout.spacingMedium)
        .padding(.vertical, ThemeLayout.spacingSmall)
        .background {
            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                .fill(Color.black.opacity(ThemeLayout.opacityHeavy))
        }
        .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
    }
}

// MARK: - Info Pills

@available(iOS 18.0, *)
struct DatePill: View {
    let date: Date
    var isFiltered: Bool = false
    
    var body: some View {
        HStack(spacing: ThemeLayout.spacingXXSmall) {
            Image(systemName: isFiltered ? "calendar.badge.checkmark" : "calendar")
                .font(.themeButtonSmall)
            Text(date.relativeString)
                .font(.themeButtonSmall)
        }
        .foregroundStyle(isFiltered ? Color.accentColor : Color.themePrimary)
        .padding(.horizontal, ThemeLayout.spacingMedium)
        .padding(.vertical, ThemeLayout.spacingSmall)
        .background {
            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                .fill(isFiltered ? Color.accentColor.opacity(0.3) : Color.black.opacity(ThemeLayout.opacityHeavy))
        }
        .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
        .accessibilityLabel(String(format: NSLocalizedString("Photo taken %@", comment: "Photo date accessibility"), date.relativeString))
    }
}

@available(iOS 18.0, *)
struct VideoPill: View {
    let duration: String
    
    var body: some View {
        HStack(spacing: ThemeLayout.spacingXXSmall) {
            Image(systemName: "play.fill")
                .font(.themeButtonSmall)
            Text(duration)
                .font(.themeButtonSmall)
                .monospacedDigit()
        }
        .foregroundStyle(Color.themePrimary)
        .padding(.horizontal, ThemeLayout.spacingMedium)
        .padding(.vertical, ThemeLayout.spacingSmall)
        .background {
            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                .fill(Color.black.opacity(ThemeLayout.opacityHeavy))
        }
        .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
        .accessibilityLabel(String(format: NSLocalizedString("Video duration %@", comment: "Video duration accessibility"), duration))
    }
}

// MARK: - Completed Stats

struct CompletedStat: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String
    var onForcePress: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: ThemeLayout.paddingSmall) {
            Image(systemName: icon)
                .font(.themeTitleLarge)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.themeTitleLarge.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.themePrimary)
            
            Text(label)
                .font(.themeLabel)
                .foregroundStyle(Color.themeSecondary)
        }
        .frame(width: ThemeLayout.compactPillWidth)
        .modifier(ForcePressModifier(onForcePress: {
            onForcePress?()
        }))
        .accessibilityLabel(label)
        .accessibilityHint(onForcePress != nil ? NSLocalizedString("Force press to add photos to album", comment: "Force press hint") : "")
    }
}
