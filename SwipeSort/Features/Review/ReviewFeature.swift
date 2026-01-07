//
//  ReviewFeature.swift
//  SwipeSort
//
//  Review delete candidates and favorites
//

import SwiftUI
import Photos

@available(iOS 26.0, *)
struct ReviewFeature: View {
    @Bindable var photoLibrary: PhotoLibraryClient
    @Bindable var sortStore: SortResultStore
    
    @State private var state = ReviewState()
    
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Segment picker
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    if state.currentItems.isEmpty {
                        emptyStateView
                    } else {
                        contentView
                    }
                }
                
                if state.isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !state.currentItems.isEmpty {
                        menuButton
                    }
                }
            }
            .task {
                refreshItems()
            }
            .onChange(of: sortStore.deleteCount) { _, _ in
                refreshItems()
            }
            .onChange(of: sortStore.favoriteCount) { _, _ in
                refreshItems()
            }
            .onChange(of: state.selectedSegment) { _, _ in
                state.clearSelection()
            }
            // Delete confirmations
            .confirmationDialog(
                "削除の確認",
                isPresented: $state.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    Task { await deleteSelected() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("\(state.selectedCount)件のメディアを削除しますか？\n\n削除されたメディアは「最近削除した項目」に移動され、30日後に完全に削除されます。")
            }
            .confirmationDialog(
                "すべて削除",
                isPresented: $state.showDeleteAll,
                titleVisibility: .visible
            ) {
                Button("すべて削除", role: .destructive) {
                    Task { await deleteAll() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("\(state.deleteItems.count)件のメディアをすべて削除しますか？\n\n削除されたメディアは「最近削除した項目」に移動され、30日後に完全に削除されます。")
            }
            // Remove favorite confirmation
            .confirmationDialog(
                "お気に入りから削除",
                isPresented: $state.showRemoveFavoriteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    Task { await removeFavoriteSelected() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("\(state.selectedCount)件をお気に入りから削除しますか？\n\n写真自体は削除されません。")
            }
            // Success message
            .alert("完了", isPresented: $state.showSuccessMessage) {
                Button("OK") {}
            } message: {
                Text(state.successMessage)
            }
            // Error message
            .alert("エラー", isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            )) {
                Button("OK") { state.errorMessage = nil }
            } message: {
                Text(state.errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Segment Picker
    
    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(ReviewSegment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.selectedSegment = segment
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: segment.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(segment.title)
                            .font(.system(size: 14, weight: .semibold))
                        
                        // Badge count
                        let count = segment == .delete ? state.deleteItems.count : state.favoriteItems.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule().fill(
                                        state.selectedSegment == segment
                                            ? .white.opacity(0.2)
                                            : .white.opacity(0.1)
                                    )
                                }
                        }
                    }
                    .foregroundStyle(state.selectedSegment == segment ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        if state.selectedSegment == segment {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(segment == .delete ? Color.deleteColor.opacity(0.3) : Color.favoriteColor.opacity(0.3))
                        }
                    }
                }
            }
        }
        .padding(4)
        .glassCard(cornerRadius: 14)
    }
    
    // MARK: - Menu Button
    
    private var menuButton: some View {
        Menu {
            Button {
                if state.allSelected {
                    state.deselectAll()
                } else {
                    state.selectAll()
                }
            } label: {
                Label(
                    state.allSelected ? "選択解除" : "すべて選択",
                    systemImage: state.allSelected ? "circle" : "checkmark.circle"
                )
            }
            
            if state.hasSelection {
                Divider()
                
                if state.selectedSegment == .delete {
                    Button(role: .destructive) {
                        state.showDeleteConfirmation = true
                    } label: {
                        Label("選択した項目を削除", systemImage: "trash")
                    }
                    
                    Button {
                        restoreFromDelete()
                    } label: {
                        Label("選択した項目を戻す", systemImage: "arrow.uturn.backward")
                    }
                } else {
                    Button(role: .destructive) {
                        state.showRemoveFavoriteConfirmation = true
                    } label: {
                        Label("お気に入りから削除", systemImage: "heart.slash")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            let (icon, title, subtitle) = emptyStateContent
            
            Image(systemName: icon)
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.white.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxHeight: .infinity)
    }
    
    private var emptyStateContent: (String, String, String) {
        switch state.selectedSegment {
        case .delete:
            return ("trash.slash", "削除候補はありません", "左にスワイプした写真がここに表示されます")
        case .favorite:
            return ("heart.slash", "お気に入りはありません", "上にスワイプした写真がここに表示されます")
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(state.currentItems) { item in
                        ReviewGridItem(
                            item: item,
                            isSelected: state.isSelected(item.id),
                            photoLibrary: photoLibrary
                        ) {
                            state.toggleSelection(for: item.id)
                        }
                    }
                }
                .padding(4)
            }
            
            // Show bottom bar only when there's something to interact with
            if state.selectedSegment == .delete && !state.currentItems.isEmpty {
                bottomActionBar
            } else if state.selectedSegment == .favorite && state.hasSelection {
                bottomActionBar
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(state.currentItems.count)件")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                
                if state.hasSelection {
                    Text("\(state.selectedCount)件選択中")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                ReviewStatBadge(icon: "checkmark", count: sortStore.keepCount, color: .keepColor)
                ReviewStatBadge(icon: "trash", count: sortStore.deleteCount, color: .deleteColor)
                ReviewStatBadge(icon: "heart.fill", count: sortStore.favoriteCount, color: .favoriteColor)
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            if state.selectedSegment == .delete {
                deleteActionBar
            } else {
                favoriteActionBar
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background {
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private var deleteActionBar: some View {
        if state.hasSelection {
            Button {
                restoreFromDelete()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("戻す")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassPill()
            }
            
            Spacer()
            
            Button {
                state.showDeleteConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("削除 (\(state.selectedCount))")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background {
                    Capsule().fill(LinearGradient.deleteGradient)
                }
            }
        } else {
            Spacer()
            
            Button {
                state.showDeleteAll = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("すべて削除")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    Capsule().fill(LinearGradient.deleteGradient)
                }
            }
        }
    }
    
    @ViewBuilder
    private var favoriteActionBar: some View {
        if state.hasSelection {
            Spacer()
            
            Button {
                state.showRemoveFavoriteConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.slash")
                    Text("お気に入り解除 (\(state.selectedCount))")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassPill()
            }
        } else {
            // No bulk action for favorites when nothing is selected
            EmptyView()
        }
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("処理中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(48)
            .glassCard()
        }
    }
    
    // MARK: - Actions
    
    private func refreshItems() {
        let deleteIDs = sortStore.deleteIDs
        let favoriteIDs = sortStore.favoriteIDs
        
        state.deleteItems = photoLibrary.assets(for: deleteIDs)
        state.favoriteItems = photoLibrary.assets(for: favoriteIDs)
        
        // Clean up selection for items that no longer exist
        let currentIDs = Set(state.currentItems.map { $0.id })
        state.selectedIDs = state.selectedIDs.intersection(currentIDs)
    }
    
    private func restoreFromDelete() {
        sortStore.remove(assetIDs: Array(state.selectedIDs))
        state.clearSelection()
        refreshItems()
        HapticFeedback.notification(.success)
    }
    
    private func deleteSelected() async {
        await deleteItems(ids: Array(state.selectedIDs))
    }
    
    private func deleteAll() async {
        await deleteItems(ids: state.deleteItems.map { $0.id })
    }
    
    private func deleteItems(ids: [String]) async {
        guard !ids.isEmpty else { return }
        
        state.isProcessing = true
        state.errorMessage = nil
        
        do {
            let assets = photoLibrary.allAssets.filter { ids.contains($0.id) }.map { $0.asset }
            try await photoLibrary.deleteAssets(assets)
            
            sortStore.remove(assetIDs: ids)
            state.clearSelection()
            
            refreshItems()
            
            state.successMessage = "メディアは「最近削除した項目」に移動されました。"
            state.showSuccessMessage = true
            HapticFeedback.notification(.success)
        } catch {
            state.errorMessage = error.localizedDescription
            HapticFeedback.notification(.error)
        }
        
        state.isProcessing = false
    }
    
    private func removeFavoriteSelected() async {
        guard !state.selectedIDs.isEmpty else { return }
        
        state.isProcessing = true
        state.errorMessage = nil
        
        do {
            // Remove from iOS favorites
            let assets = photoLibrary.allAssets.filter { state.selectedIDs.contains($0.id) }.map { $0.asset }
            try await photoLibrary.setFavorite(assets, isFavorite: false)
            
            // Remove from app's favorite list
            sortStore.remove(assetIDs: Array(state.selectedIDs))
            state.clearSelection()
            
            refreshItems()
            
            state.successMessage = "お気に入りから削除しました。"
            state.showSuccessMessage = true
            HapticFeedback.notification(.success)
        } catch {
            state.errorMessage = error.localizedDescription
            HapticFeedback.notification(.error)
        }
        
        state.isProcessing = false
    }
}

// MARK: - Review Grid Item

@available(iOS 26.0, *)
struct ReviewGridItem: View {
    let item: PhotoAsset
    let isSelected: Bool
    let photoLibrary: PhotoLibraryClient
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            ProgressView().tint(.white.opacity(0.5))
                        }
                }
                
                if isSelected {
                    Rectangle().fill(.blue.opacity(0.4))
                    
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .blue)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
                
                if item.isVideo {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                            Text(item.formattedDuration)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            thumbnail = await photoLibrary.loadThumbnail(for: item.asset)
        }
    }
}

// MARK: - Review Stat Badge

@available(iOS 26.0, *)
struct ReviewStatBadge: View {
    let icon: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text("\(count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(Color.white.opacity(0.12))
        }
    }
}
