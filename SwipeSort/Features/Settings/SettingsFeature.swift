//
//  SettingsFeature.swift
//  SwipeSort
//
//  Settings and configuration view
//

import SwiftUI

struct SettingsFeature: View {
    @Bindable var sortStore: SortResultStore
    
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    
    @State private var showResetConfirmation = false
    @State private var showAbout = false
    
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
                    
                    // About
                    aboutCard
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .confirmationDialog(
                "データをリセット",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("リセット", role: .destructive) {
                    sortStore.reset()
                    HapticFeedback.notification(.success)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("すべての整理結果とUndo履歴が削除されます。この操作は取り消せません。")
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        VStack(spacing: 20) {
            HStack {
                Text("統計")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            HStack(spacing: 16) {
                StatisticItem(
                    count: sortStore.keepCount,
                    label: "Keep",
                    color: .keepColor,
                    icon: "checkmark.circle.fill"
                )
                
                StatisticItem(
                    count: sortStore.deleteCount,
                    label: "削除",
                    color: .deleteColor,
                    icon: "trash.circle.fill"
                )
                
                StatisticItem(
                    count: sortStore.favoriteCount,
                    label: "お気に入り",
                    color: .favoriteColor,
                    icon: "heart.circle.fill"
                )
            }
            
            Divider()
                .background(.white.opacity(0.1))
            
            HStack {
                Text("合計")
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(sortStore.totalSortedCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("枚")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        }
    }
    
    // MARK: - Gesture Guide Card
    
    private var gestureGuideCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("操作方法")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            
            VStack(spacing: 12) {
                GestureRow(
                    icon: "arrow.right",
                    direction: "右スワイプ",
                    action: "Keep",
                    color: .keepColor
                )
                GestureRow(
                    icon: "arrow.left",
                    direction: "左スワイプ",
                    action: "削除候補",
                    color: .deleteColor
                )
                GestureRow(
                    icon: "arrow.up",
                    direction: "上スワイプ",
                    action: "お気に入り",
                    color: .favoriteColor
                )
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        }
    }
    
    // MARK: - Settings Card
    
    private var settingsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("設定")
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
                        Text("触覚フィードバック")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Text("スワイプ時に振動")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .tint(.purple)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        }
    }
    
    // MARK: - Data Card
    
    private var dataCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("データ")
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
                        Text("データをリセット")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Text("すべての整理結果を削除")
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
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        }
    }
    
    // MARK: - About Card
    
    private var aboutCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("情報")
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
                        title: "SwipeSortについて",
                        showChevron: true
                    )
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.leading, 48)
                
                Link(destination: URL(string: "https://apple.com/legal/privacy")!) {
                    SettingsRow(
                        icon: "hand.raised",
                        iconColor: .green,
                        title: "プライバシーポリシー",
                        showChevron: true,
                        isExternal: true
                    )
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        }
    }
}

// MARK: - Supporting Views

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
                            
                            Text("バージョン 1.0")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SwipeSortについて")
                                .font(.system(size: 17, weight: .semibold))
                            
                            Text("直感的なスワイプ操作で写真を簡単に整理できるアプリです。大量の写真も素早くKeep・削除・お気に入りに分類できます。")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("操作方法")
                                .font(.system(size: 17, weight: .semibold))
                            
                            VStack(spacing: 12) {
                                InstructionRow(
                                    icon: "arrow.right.circle.fill",
                                    color: .keepColor,
                                    text: "右スワイプ",
                                    description: "Keep（残す）"
                                )
                                InstructionRow(
                                    icon: "arrow.left.circle.fill",
                                    color: .deleteColor,
                                    text: "左スワイプ",
                                    description: "削除候補"
                                )
                                InstructionRow(
                                    icon: "arrow.up.circle.fill",
                                    color: .favoriteColor,
                                    text: "上スワイプ",
                                    description: "お気に入り"
                                )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("削除について")
                                .font(.system(size: 17, weight: .semibold))
                            
                            Text("削除候補に分類した写真は「確認」タブで確認・削除できます。削除された写真はiOSの「最近削除した項目」に移動し、30日以内であれば復元できます。")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("SwipeSortについて")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

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
