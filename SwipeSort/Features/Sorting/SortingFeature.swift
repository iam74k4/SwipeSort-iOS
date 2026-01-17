//
//  SortingFeature.swift
//  SwipeSort
//
//  Main sorting view with integrated state management
//

import SwiftUI
@preconcurrency import Photos
import PhotosUI
import UIKit

@available(iOS 18.0, *)
struct SortingFeature: View {
    @Bindable var photoLibrary: PhotoLibraryClient
    @Bindable var sortStore: SortResultStore
    
    @State private var state = SortingState()

    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showSwipeHint = false
    
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundGradient
                
                if state.showingBurstSelector {
                    burstSelectorOverlay
                } else if state.isComplete {
                    completedView
                } else if let asset = state.currentAsset {
                    photoViewerContent(for: asset, in: geometry)
                } else if photoLibrary.isLoading {
                    loadingView
                } else {
                    emptyView
                }
            }
        }
        .task {
            await loadAssets()
        }
        .alert(NSLocalizedString("Delete Failed", comment: "Delete failed alert title"), isPresented: $showDeleteError) {
            Button(NSLocalizedString("OK", comment: "OK button")) {}
        } message: {
            Text(deleteErrorMessage)
        }
        .confirmationDialog(
            String(format: NSLocalizedString("Delete %d Items?", comment: "Delete confirmation"), state.deleteQueue.count),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Delete", comment: "Delete button"), role: .destructive) {
                Task { await flushDeleteQueue() }
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Deleted photos will be moved to Recently Deleted.", comment: "Delete confirmation message"))
        }
    }
    
    // MARK: - Burst Selector Overlay
    
    private var burstSelectorOverlay: some View {
        BurstSelectorView(
            burstAssets: state.burstAssets,
            photoLibrary: photoLibrary,
            onSelect: { selected, others in
                // Keep selected, add others to delete queue
                let previousCategory = sortStore.category(for: selected.id)
                sortStore.addOrUpdate(assetID: selected.id, category: .keep, previousCategory: previousCategory, recordUndo: true)
                
                // 選択した写真をリストから除外
                state.removeAsset(selected)
                
                // 他の写真を削除キューに追加
                for other in others {
                    let otherPreviousCategory = sortStore.category(for: other.id)
                    // Undo記録を作成（削除キューに入れたことを記録）
                    sortStore.createUndoRecord(assetID: other.id, previousCategory: otherPreviousCategory)
                    // 削除キューに入れるだけ（実際に削除されるまで削除カテゴリとして記録しない）
                    state.deleteQueue.append(other)
                    state.removeAsset(other)
                }
                
                state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
                state.updateCurrentAsset()
                state.resetBurstSelector()
                
                // 自動削除は行わない（ユーザーが「削除」ボタンを押すまで待つ）
                if state.unsortedAssets.isEmpty {
                    state.isComplete = true
                } else {
                    Task { await loadCurrentImage() }
                }
                
                HapticFeedback.notification(.success)
            },
            onCancel: {
                // Skip burst selection, continue with normal sorting
                state.resetBurstSelector()
            },
            onKeepAll: {
                // Mark all burst photos as keep
                for asset in state.burstAssets {
                    let previousCategory = sortStore.category(for: asset.id)
                    sortStore.addOrUpdate(assetID: asset.id, category: .keep, previousCategory: previousCategory, recordUndo: true)
                    state.removeAsset(asset)
                }
                
                state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
                state.updateCurrentAsset()
                state.resetBurstSelector()
                
                if state.unsortedAssets.isEmpty {
                    state.isComplete = true
                } else {
                    Task { await loadCurrentImage() }
                }
                
                HapticFeedback.impact(.medium)
            }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            Color.appBackground
            
            // Subtle ambient gradient based on swipe direction
            switch state.swipeDirection {
            case .right:
                RadialGradient(
                    colors: [.keepColor.opacity(0.15), .clear],
                    center: .trailing,
                    startRadius: 0,
                    endRadius: 400
                )
                .animation(.easeOut(duration: 0.2), value: state.swipeDirection)
            case .left:
                RadialGradient(
                    colors: [.deleteColor.opacity(0.15), .clear],
                    center: .leading,
                    startRadius: 0,
                    endRadius: 400
                )
                .animation(.easeOut(duration: 0.2), value: state.swipeDirection)
            case .up:
                RadialGradient(
                    colors: [.skipColor.opacity(0.15), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .animation(.easeOut(duration: 0.2), value: state.swipeDirection)
            case .none:
                Color.clear
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Photo Viewer Content
    
    private func photoViewerContent(for asset: PhotoAsset, in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top bar
            topBar(asset: asset, geometry: geometry)
                .background(Color.appBackground)
            
            // Photo card area
            ZStack {
                photoCardStack(in: geometry)
                
                // Swipe indicator
                SwipeOverlay(direction: state.swipeDirection, progress: state.swipeProgress)
                    .allowsHitTesting(false)
                
                // Heart animation for double tap
                if state.showHeartAnimation {
                    HeartAnimationView(isAnimating: $state.showHeartAnimation)
                }
                
                // First-time swipe hint
                if showSwipeHint {
                    SwipeHintOverlay {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showSwipeHint = false
                            hasSeenSwipeHint = true
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()
            
            // Bottom section
            bottomSection(asset: asset, geometry: geometry)
                .background(Color.appBackground)
        }
    }
    
    // MARK: - Photo Card Stack
    
    private func photoCardStack(in geometry: GeometryProxy) -> some View {
        GeometryReader { cardGeometry in
            let cardWidth = cardGeometry.size.width - 8
            let cardHeight = cardGeometry.size.height - 8
            
            ZStack {
                // Next card preview (behind) - uses app background to blend seamlessly
                if state.unsortedAssets.count > 1 {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.appBackground)
                        .frame(width: cardWidth, height: cardHeight)
                        .offset(y: 6)
                        .scaleEffect(0.97)
                }
                
                // Current photo card
                photoCard(width: cardWidth, height: cardHeight)
                    .offset(state.offset)
                    .scaleEffect(cardScale, anchor: .center)
                    .rotationEffect(.degrees(cardRotation))
                    .onTapGesture(count: 2) {
                        performFavorite()
                    }
                    .gesture(dragGesture)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
        .animation(.photoSlide, value: state.offset)
    }
    
    private var cardScale: CGFloat {
        // Only scale during drag, not during animations
        guard !state.isAnimatingOut else { return 1.0 }
        guard state.offset != .zero else { return 1.0 }
        return 1.0 - abs(state.offset.width) / 3000
    }
    
    private var cardRotation: Double {
        Double(state.offset.width) / 25
    }
    
    private func photoCard(width cardWidth: CGFloat, height cardHeight: CGFloat) -> some View {
        ZStack {
            // Card background (matches app background to hide Aspect Fit padding)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appBackground)
            
            // Photo content (Live Photo or regular)
            photoContentView
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Media type badges (top-left)
            if let asset = state.currentAsset {
                mediaBadges(for: asset)
            }
            
            // Action stamp overlay
            actionStamp(cardWidth: cardWidth, cardHeight: cardHeight)
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .opacity(state.imageOpacity)
        .animation(.easeOut(duration: 0.2), value: state.imageOpacity)
        .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
            guard let asset = state.currentAsset else { return }
                state.isLongPressing = pressing

            if asset.isLivePhoto {
                if pressing && state.currentLivePhoto != nil {
                    state.isPlayingLivePhoto = true
                    HapticFeedback.impact(.light)
                } else {
                    state.isPlayingLivePhoto = false
                }
            } else if asset.isVideo {
                if pressing {
                    state.isPlayingVideo = true
                    HapticFeedback.impact(.light)
                } else {
                    state.isPlayingVideo = false
                }
            }
        }, perform: {})
    }
    
    // MARK: - Media Badges
    
    @ViewBuilder
    private func mediaBadges(for asset: PhotoAsset) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if asset.isLivePhoto {
                        MediaBadge(type: .live)
                    }
                    if asset.isRAW {
                        MediaBadge(type: .raw)
                    }
                    if asset.isBurstPhoto, let count = state.currentBurstCount, count > 1 {
                        Button {
                            openBurstSelector(for: asset)
                        } label: {
                            MediaBadge(type: .burst(count: count))
                        }
                    }
                }
                .padding(12)
                Spacer()
            }
            Spacer()
        }
    }
    
    private func openBurstSelector(for asset: PhotoAsset) {
        guard let burstId = asset.burstIdentifier else { return }
        
        state.burstAssets = photoLibrary.fetchBurstAssets(for: burstId)
        if state.burstAssets.count > 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                state.showingBurstSelector = true
            }
        }
    }
    
    // MARK: - Action Stamp
    
    @ViewBuilder
    private func actionStamp(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let progress = state.swipeProgress
        
        if progress > 0.3 {
            Group {
                switch state.swipeDirection {
                case .right:
                    StampView(text: "KEEP", color: .keepColor, rotation: -15)
                        .position(x: cardWidth * 0.35, y: cardHeight * 0.18)
                case .left:
                    StampView(text: "DELETE", color: .deleteColor, rotation: 15)
                        .position(x: cardWidth * 0.65, y: cardHeight * 0.18)
                case .up:
                    StampView(text: "SKIP", color: .skipColor, rotation: 0)
                        .position(x: cardWidth * 0.5, y: cardHeight * 0.85)
                        .scaleEffect(1.1)  // Slightly larger for better visibility
                case .none:
                    EmptyView()
                }
            }
            .opacity(min((progress - 0.3) * 2, 1.0))
            .scaleEffect(0.8 + min((progress - 0.3), 0.2))
        }
    }
    
    // MARK: - Photo Content
    
    @ViewBuilder
    private var photoContentView: some View {
        if state.isLoadingImage {
            ZStack {
                Color.appBackground
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        } else if state.isPlayingLivePhoto, let livePhoto = state.currentLivePhoto {
            // Live Photo playback
            ZStack {
                Color.appBackground
            LivePhotoPlayerView(livePhoto: livePhoto, isPlaying: $state.isPlayingLivePhoto)
            }
        } else if state.isPlayingVideo, let asset = state.currentAsset {
            ZStack {
                Color.appBackground
                VideoPlayerView(asset: asset.asset, isPlaying: $state.isPlayingVideo)
            }
        } else if let image = state.currentImage {
            ZStack {
                Color.appBackground
            Image(uiImage: image)
                .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            ZStack {
                Color.appBackground
                Image(systemName: "photo")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }
    
    // MARK: - Top Bar
    
    private func topBar(asset: PhotoAsset, geometry: GeometryProxy) -> some View {
        HStack(spacing: 6) {
            // Filter button
            filterButton
            
            // Stats (tappable for filtering)
            HStack(spacing: 4) {
                Button {
                    withAnimation(.overlayFade) {
                        if state.selectedCategoryFilter == .keep {
                            state.applyCategoryFilter(nil, sortStore: sortStore)
                        } else {
                            state.applyCategoryFilter(.keep, sortStore: sortStore)
                        }
                    }
                    Task { await loadCurrentImage() }
                } label: {
                    StatPill(
                        count: sortStore.keepCount,
                        color: .keepColor,
                        icon: "checkmark",
                        isSelected: state.selectedCategoryFilter == .keep
                    )
                }
                .buttonStyle(.plain)
                
                // 削除キューがある場合は削除待ち件数を表示
                if state.deleteQueue.isEmpty {
                    Button {
                        withAnimation(.overlayFade) {
                            if state.selectedCategoryFilter == .delete {
                                state.applyCategoryFilter(nil, sortStore: sortStore)
                            } else {
                                state.applyCategoryFilter(.delete, sortStore: sortStore)
                            }
                        }
                        Task { await loadCurrentImage() }
                    } label: {
                        StatPill(
                            count: sortStore.deleteCount,
                            color: .deleteColor,
                            icon: "trash",
                            isSelected: state.selectedCategoryFilter == .delete
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.overlayFade) {
                            if state.selectedCategoryFilter == .delete {
                                state.applyCategoryFilter(nil, sortStore: sortStore)
                            } else {
                                state.applyCategoryFilter(.delete, sortStore: sortStore)
                            }
                        }
                        Task { await loadCurrentImage() }
                    } label: {
                        DeleteQueuePill(
                            queueCount: state.deleteQueue.count,
                            isSelected: state.selectedCategoryFilter == .delete
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    withAnimation(.overlayFade) {
                        if state.selectedCategoryFilter == .favorite {
                            state.applyCategoryFilter(nil, sortStore: sortStore)
                        } else {
                            state.applyCategoryFilter(.favorite, sortStore: sortStore)
                        }
                    }
                    Task { await loadCurrentImage() }
                } label: {
                    StatPill(
                        count: sortStore.favoriteCount,
                        color: .favoriteColor,
                        icon: "heart.fill",
                        isSelected: state.selectedCategoryFilter == .favorite
                    )
            }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.overlayFade) {
                        if state.selectedCategoryFilter == .unsorted {
                            state.applyCategoryFilter(nil, sortStore: sortStore)
                        } else {
                            state.applyCategoryFilter(.unsorted, sortStore: sortStore)
                        }
                    }
                    Task { await loadCurrentImage() }
                } label: {
                    StatPill(
                        count: sortStore.unsortedCount,
                        color: .skipColor,
                        icon: "arrow.up",
                        isSelected: state.selectedCategoryFilter == .unsorted
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer(minLength: 6)
            
            // Progress
            ProgressPill(current: sortStore.totalSortedCount + 1, total: state.totalCount)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Filter Button
    
    private var filterButton: some View {
        Menu {
            ForEach(MediaFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.overlayFade) {
                        state.applyFilter(filter, sortStore: sortStore)
                    }
                    Task { await loadCurrentImage() }
                } label: {
                    Label {
                        HStack {
                            Text(filter.localizedName)
                            if filter == state.currentFilter {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    } icon: {
                        Image(systemName: filter.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: state.currentFilter.icon)
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 9) // アイコンの固定幅
                if state.currentFilter != .all {
                    Text(state.currentFilter.localizedName)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 50)
                }
            }
            .foregroundStyle(.white.opacity(state.currentFilter == .all ? 0.7 : 0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: state.currentFilter == .all ? nil : 70) // フィルター選択時は固定幅
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.12))
            }
            .overlay {
                if state.currentFilter != .all {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                }
            }
        }
        .id(state.currentFilter) // フィルター変更時にビューを再作成してレイアウトを安定させる
    }
    
    // MARK: - Bottom Section
    
    private func bottomSection(asset: PhotoAsset, geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // Media info chips
            HStack(spacing: 8) {
                // Date chip
                if let date = asset.creationDate {
                    DateChip(date: date)
                }
                
                // Video duration
            if asset.isVideo {
                VideoChip(duration: asset.formattedDuration)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Undo button
            undoButton
                .opacity(sortStore.canUndo ? 1 : 0)
                
                // Delete queue button
                if !state.deleteQueue.isEmpty {
                    deleteQueueButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: sortStore.canUndo)
        .animation(.easeInOut(duration: 0.2), value: state.deleteQueue.count)
    }
    
    // MARK: - Undo Button
    
    private var undoButton: some View {
        Button {
            Task {
                await performUndo()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .semibold))
                Text(NSLocalizedString("Undo", comment: "Undo button"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassPill()
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .disabled(state.isUndoing || !sortStore.canUndo)
        .opacity((state.isUndoing || !sortStore.canUndo) ? 0.5 : 1.0)
    }
    
    // MARK: - Delete Queue Button
    
    private var deleteQueueButton: some View {
        HStack(spacing: 0) {
            // Delete button (left side)
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(state.deleteQueue.count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 20)
            
            // Clear queue button (right side)
            Button {
        withAnimation(.buttonPress) {
            clearDeleteQueue()
        }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background {
            Capsule()
                .fill(Color.deleteColor)
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: Color.deleteColor.opacity(0.3), radius: 6, x: 0, y: 3)
    }
    
    private func clearDeleteQueue() {
        // 削除キューをクリアして、アセットを未整理に戻す
        for asset in state.deleteQueue {
            // 削除記録を削除（存在する場合）
            sortStore.remove(assetID: asset.id)
            // Undo記録も削除
            sortStore.removeUndoRecord(for: asset.id)
            
            state.restoreAssetToUnsorted(asset, atStart: false)
        }
        state.deleteQueue.removeAll()
        state.isComplete = false
        
        // 現在のアセットを更新
        state.currentIndex = 0
        state.updateCurrentAsset()
        
        Task { await loadCurrentImage() }
        
        HapticFeedback.impact(.light)
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                state.offset = value.translation
                
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                // Determine primary direction based on magnitude
                if abs(horizontal) > abs(vertical) {
                    // Horizontal swipe
                    if horizontal > SwipeThreshold.detectionStart {
                    state.swipeDirection = .right
                    } else if horizontal < -SwipeThreshold.detectionStart {
                    state.swipeDirection = .left
                } else {
                    state.swipeDirection = .none
                    }
                } else {
                    // Vertical swipe (only up for skip)
                    if vertical < -SwipeThreshold.detectionStart {
                        state.swipeDirection = .up
                    } else {
                        state.swipeDirection = .none
                    }
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                // Determine completion based on primary direction
                if abs(horizontal) > abs(vertical) {
                if horizontal > SwipeThreshold.horizontal {
                    completeSwipe(direction: .right)
                } else if horizontal < -SwipeThreshold.horizontal {
                    completeSwipe(direction: .left)
                } else {
                    resetPosition()
                    }
                } else {
                    if vertical < -SwipeThreshold.vertical {
                        completeSwipe(direction: .up)
                    } else {
                        resetPosition()
                    }
                }
            }
    }
    
    // MARK: - Actions
    
    private func completeSwipe(direction: SwipeDirection) {
        guard direction != .none, !state.isAnimatingOut else { return }
        
        state.isAnimatingOut = true
        
        Task { await preloadNextImage() }
        
        withAnimation(.easeOut(duration: 0.3)) {
            switch direction {
            case .right:
                state.offset = CGSize(width: 500, height: 50)
            case .left:
                state.offset = CGSize(width: -500, height: 50)
            case .up:
                state.offset = CGSize(width: 0, height: -500)
            case .none:
                break
            }
            state.imageOpacity = 0
        }
        
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            await processSort(direction: direction)
            
            // Clear old image before loading next
            state.currentImage = nil
            state.currentLivePhoto = nil
            
            // 次の画像を読み込む（nextImageが既に読み込まれている場合はそれを使用）
            if let next = state.nextImage {
                state.currentImage = next
                state.nextImage = nil
            } else {
                // nextImageが読み込まれていない場合は、現在のアセットの画像を読み込む
                await loadCurrentImage()
            }
            
            state.offset = .zero
            state.swipeDirection = .none
            state.isAnimatingOut = false
            
            state.imageOpacity = 0
            withAnimation(.easeIn(duration: 0.2)) {
                state.imageOpacity = 1.0
            }
        }
    }
    
    private func processSort(direction: SwipeDirection) async {
        guard let asset = state.currentAsset else { return }
        
        switch direction {
        case .right:
            let previousCategory = sortStore.category(for: asset.id)
            sortStore.addOrUpdate(assetID: asset.id, category: .keep, previousCategory: previousCategory, recordUndo: true)
            HapticFeedback.impact(.medium)
            state.removeAsset(asset)
        case .left:
            HapticFeedback.impact(.heavy)
            // キューに追加（まとめて削除でiOS確認ダイアログを減らす）
            // 削除キューに追加した時点では削除カテゴリとして記録しない（実際に削除されるまでカウントしない）
            // Undo記録は作成する（戻すボタンを表示するため）
            let previousCategory = sortStore.category(for: asset.id)
            // Undo記録を作成（削除キューに入れたことを記録）
            sortStore.createUndoRecord(assetID: asset.id, previousCategory: previousCategory)
            // 削除キューに入れるだけ（まだ削除カテゴリとして記録しない）
            state.deleteQueue.append(asset)
            state.removeAsset(asset)
        case .up:
            // Skip: move to end of list (decide later)
            HapticFeedback.impact(.light)
            // スキップを未整理として記録（統計に表示するため）
            let previousCategory = sortStore.category(for: asset.id)
            sortStore.addOrUpdate(assetID: asset.id, category: .unsorted, previousCategory: previousCategory, recordUndo: true)
            state.moveToEnd(asset)
        case .none:
            break
        }
        
        state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
        state.updateCurrentAsset()
        
        // 自動削除は行わない（ユーザーが「削除」ボタンを押すまで待つ）
        
        // isCompleteは実際にすべてのアセットが整理された場合のみtrue（フィルター結果ではない）
        if state.allUnsortedAssets.isEmpty {
            state.isComplete = true
        }
    }
    
    private func performFavorite() {
        guard let asset = state.currentAsset, !state.isAnimatingOut else { return }
        
        // Show heart animation
        state.showHeartAnimation = true
        HapticFeedback.notification(.success)
        
        // Add to favorites
        let previousCategory = sortStore.category(for: asset.id)
        sortStore.addOrUpdate(assetID: asset.id, category: .favorite, previousCategory: previousCategory, recordUndo: true)
        
        // Add to iOS Favorites album
        Task {
            do {
                try await photoLibrary.setFavorite(asset.asset, isFavorite: true)
            } catch {
                // Non-critical: Favorite status update failed, but sorting continues
                // Error is logged silently as this doesn't affect the core sorting functionality
            }
        }
        
        // Animate out after heart animation
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            
            await preloadNextImage()
            
            state.isAnimatingOut = true
            
            withAnimation(.easeOut(duration: 0.25)) {
                state.imageOpacity = 0
            }
            
            try? await Task.sleep(for: .milliseconds(250))
            
            // Clear old image before moving to next
            state.currentImage = nil
            state.currentLivePhoto = nil
            
            // Move to next
            state.removeAsset(asset)
            state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
            state.updateCurrentAsset()
            
            // isCompleteは実際にすべてのアセットが整理された場合のみtrue（フィルター結果ではない）
            if state.allUnsortedAssets.isEmpty {
                state.isComplete = true
            }
            
            if let next = state.nextImage {
                state.currentImage = next
                state.nextImage = nil
            }
            
            state.isAnimatingOut = false
            
            withAnimation(.easeIn(duration: 0.2)) {
                state.imageOpacity = 1.0
            }
        }
    }
    
    private func performUndo() async {
        // 連打防止: 既にUndo処理中またはアニメーション中の場合、処理をスキップ
        guard !state.isUndoing, !state.isAnimatingOut else { return }
        
        // Undo処理開始
        state.isUndoing = true
        
        state.offset = CGSize(width: -400, height: 0)
        state.imageOpacity = 0
        
        if let assetID = sortStore.undo() {
            // 削除キューからも取り消す（削除キューに含まれている場合）
            if let index = state.deleteQueue.firstIndex(where: { $0.id == assetID }) {
                let asset = state.deleteQueue[index]
                state.deleteQueue.remove(at: index)
                
                // undo()で既にpreviousCategoryに戻されているので、ここでは削除キューから取り消すだけ
                // アセットを未整理リストに戻す（undo()でカテゴリが未整理に戻された場合）
                let currentCategory = sortStore.category(for: assetID)
                if currentCategory == nil || currentCategory == .unsorted {
                    state.restoreAssetToUnsorted(asset, atStart: true)
                }
            } else if let asset = photoLibrary.allAssets.first(where: { $0.id == assetID }) {
                // 通常のUndo処理（削除キューに含まれていない場合）
                // undo()で既にpreviousCategoryに戻されている
                // If the undone action was a favorite, remove from iOS Favorites
                let currentCategory = sortStore.category(for: assetID)
                if currentCategory == .favorite {
                    do {
                        try await photoLibrary.setFavorite(asset.asset, isFavorite: false)
                    } catch {
                        // Non-critical: Favorite status update failed, but undo continues
                        // Error is logged silently as this doesn't affect the core undo functionality
                    }
                }
                
                // カテゴリが未整理に戻された場合のみ、未整理リストに追加
                if currentCategory == nil || currentCategory == .unsorted {
                    state.restoreAssetToUnsorted(asset, atStart: true)
                }
            }
            
                state.currentIndex = 0
                state.updateCurrentAsset()
                state.isComplete = false
        }
        
        await loadCurrentImage()
        
        withAnimation(.photoSlide) {
            state.offset = .zero
            state.imageOpacity = 1.0
        }
        
        HapticFeedback.impact(.light)
        
        // Undo処理完了
        state.isUndoing = false
    }
    
    private func resetPosition() {
        withAnimation(.buttonPress) {
            state.offset = .zero
            state.swipeDirection = .none
            state.imageOpacity = 1.0
        }
    }
    
    // MARK: - Loading
    
    private func loadAssets() async {
        let allAssets = await photoLibrary.fetchAllAssets()
        let sortedIDs = sortStore.sortedIDs
        
        state.allAssets = allAssets  // 全アセットを保持（カテゴリフィルター用）
        state.allUnsortedAssets = allAssets.filter { !sortedIDs.contains($0.id) }
        state.totalCount = allAssets.count
        state.applyFilter(state.currentFilter, sortStore: sortStore)  // Apply current filter with category filter
        
        await loadCurrentImage()
        
        // Show swipe hint for first-time users
        if !hasSeenSwipeHint && !state.unsortedAssets.isEmpty {
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.3)) {
                showSwipeHint = true
            }
        }
    }
    
    private func loadCurrentImage() async {
        guard let asset = state.currentAsset else {
            // Clear old images when no asset
            state.currentImage = nil
            state.currentLivePhoto = nil
            state.currentBurstCount = nil
            return
        }
        
        // 読み込み対象のアセットIDを保存（競合状態を防ぐため）
        let targetAssetID = asset.id
        
        // Clear old images before loading new ones to free memory
        state.currentImage = nil
        state.currentLivePhoto = nil
        
        state.isLoadingImage = true
        state.imageOpacity = 0
        
        // Calculate optimal image size based on screen size and Retina scale
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        // Use screen width/height with 2x scale for Retina, but cap at reasonable maximum
        let optimalSize = CGSize(
            width: min(screenSize.width * scale * 2, 2400),
            height: min(screenSize.height * scale * 2, 2400)
        )
        
        // Load main image (use fast preview for RAW images)
        let image = await photoLibrary.loadImage(
            for: asset.asset,
            targetSize: optimalSize,
            preferFastPreview: asset.isRAW
        )
        
        // アセットが変更されていないことを確認（競合状態を防ぐ）
        guard state.currentAsset?.id == targetAssetID else {
            state.isLoadingImage = false
            return
        }
        
        state.currentImage = image
        state.isLoadingImage = false
        
        withAnimation(.easeIn(duration: 0.25)) {
            state.imageOpacity = 1.0
        }
        
        // Parallel loading: Load Live Photo and burst count concurrently
        async let livePhotoTask: PHLivePhoto? = asset.isLivePhoto ? photoLibrary.loadLivePhoto(for: asset.asset, targetSize: optimalSize) : nil
        
        // Capture burstIdentifier for burst count task
        let burstId = asset.burstIdentifier
        async let burstCountTask: Int? = {
            if let burstId = burstId {
                // fetchBurstAssets is nonisolated, but photoLibrary is MainActor-isolated
                // So we need to call it from MainActor context
                let burstAssets = await photoLibrary.fetchBurstAssets(for: burstId)
                return burstAssets.count > 1 ? burstAssets.count : nil
            }
            return nil
        }()
        
        // Wait for both tasks to complete
        let (livePhoto, burstCount) = await (livePhotoTask, burstCountTask)
        
        // アセットが変更されていないことを確認
        guard state.currentAsset?.id == targetAssetID else {
            state.isLoadingImage = false
            return
        }
        
        // Update state with results
        state.currentLivePhoto = livePhoto
        state.currentBurstCount = burstCount

        // Video itemは再生時に毎回新しいインスタンスを作成するため、
        // ここでは読み込まない（VideoPlayerView内で読み込む）
        
        photoLibrary.updateCacheWindow(currentIndex: state.currentIndex, assets: state.unsortedAssets)
        
        await preloadNextImage()
    }

    private func deleteAsset(_ asset: PhotoAsset) async -> Bool {
        do {
            try await photoLibrary.deleteAssets([asset.asset])
            return true
        } catch {
            deleteErrorMessage = NSLocalizedString("Delete Failed Message", comment: "Delete failed error message")
            showDeleteError = true
            return false
        }
    }
    
    /// キューに溜まった削除対象をまとめて削除（iOS確認ダイアログ1回で済む）
    private func flushDeleteQueue() async {
        guard !state.deleteQueue.isEmpty else { return }
        
        let assetsToDelete = state.deleteQueue
        state.deleteQueue.removeAll()
        
        do {
            try await photoLibrary.deleteAssets(assetsToDelete.map { $0.asset })
            // 削除成功時：削除カテゴリとして記録（実際に削除された時点でカウントに含める）
            for asset in assetsToDelete {
                // 既存のUndo記録を削除（実際に削除されたため、Undoできない）
                sortStore.removeUndoRecord(for: asset.id)
                
                let previousCategory = sortStore.category(for: asset.id)
                // 実際に削除された時点で削除カテゴリとして記録（Undo記録は作成しない）
                sortStore.addOrUpdate(assetID: asset.id, category: .delete, previousCategory: previousCategory, recordUndo: false)
            }
        } catch {
            // 削除失敗時：削除キューを復元（Undo記録はそのまま残す）
            state.deleteQueue = assetsToDelete
            for asset in assetsToDelete {
                // 削除記録を削除（実際には削除されていないため）
                sortStore.remove(assetID: asset.id)
                // アセットを未整理リストに戻す
                state.restoreAssetToUnsorted(asset, atStart: false)
            }
            state.isComplete = false
            state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
            state.updateCurrentAsset()
            
            deleteErrorMessage = String(format: NSLocalizedString("Delete Failed Multiple", comment: "Delete failed multiple error message"), assetsToDelete.count)
            showDeleteError = true
        }
    }
    
    private func preloadNextImage() async {
        // Preload multiple images in parallel for smoother swiping
        let cacheAheadCount = 5
        let startIndex = state.currentIndex + 1
        let endIndex = min(startIndex + cacheAheadCount, state.unsortedAssets.count)
        
        guard startIndex < state.unsortedAssets.count else {
            state.nextImage = nil
            return
        }
        
        // Calculate optimal image size for preloading
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let optimalSize = CGSize(
            width: min(screenSize.width * scale * 2, 2400),
            height: min(screenSize.height * scale * 2, 2400)
        )
        
        // Load first image synchronously for immediate use
        let nextAsset = state.unsortedAssets[startIndex]
        state.nextImage = await photoLibrary.loadImage(for: nextAsset.asset, targetSize: optimalSize)
        
        // Preload remaining images in parallel (they'll be cached by PhotoLibraryClient)
        if endIndex > startIndex + 1 {
            await withTaskGroup(of: Void.self) { group in
                for i in (startIndex + 1)..<endIndex {
                    let asset = state.unsortedAssets[i]
                    group.addTask {
                        _ = await self.photoLibrary.loadImage(for: asset.asset, targetSize: optimalSize)
                    }
                }
            }
        }
    }
    
    // MARK: - State Views
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 64, height: 64)
                
                Circle()
                    .trim(from: 0, to: photoLibrary.loadingProgress)
                    .stroke(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: photoLibrary.loadingProgress)
                
                Text("\(Int(photoLibrary.loadingProgress * 100))%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Text(NSLocalizedString("Loading Photos...", comment: "Loading photos message"))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    private var emptyView: some View {
        // Check if filter is active
        let isFilterActive = state.currentFilter != .all || state.selectedCategoryFilter != nil
        
        return VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle" : "photo.on.rectangle.angled")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            VStack(spacing: 12) {
                Text(isFilterActive ? NSLocalizedString("No Matching Photos", comment: "No matching photos message") : NSLocalizedString("No Photos", comment: "No photos message"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(isFilterActive ? NSLocalizedString("No Matching Photos Description", comment: "No matching photos description") : NSLocalizedString("No Photos Description", comment: "No photos description"))
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            if isFilterActive {
                // Clear filter button (main action when filter is active)
                Button {
                    withAnimation(.buttonPress) {
                        state.applyCategoryFilter(nil, sortStore: sortStore)
                        state.applyFilter(.all, sortStore: sortStore)
                    }
                } label: {
                    Text(NSLocalizedString("Clear Filter", comment: "Clear filter button"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                }
                .padding(.horizontal, 40)
            } else {
                // Reload button (main action when no filter and no photos)
                Button {
                    Task {
                        await loadAssets()
                    }
                } label: {
                    Text(NSLocalizedString("Reload", comment: "Reload button"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var completedView: some View {
        VStack(spacing: 32) {
            // Success animation
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.keepColor.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(Color.keepColor)
            }
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("All Done!", comment: "All done title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(NSLocalizedString("All photos have been sorted.", comment: "All photos sorted message"))
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Stats
            HStack(spacing: 16) {
                CompletedStat(count: sortStore.keepCount, label: "Keep", color: .keepColor, icon: "checkmark.circle.fill")
                CompletedStat(count: sortStore.deleteCount, label: NSLocalizedString("Deleted", comment: "Deleted label"), color: .deleteColor, icon: "trash.circle.fill")
                CompletedStat(count: sortStore.favoriteCount, label: NSLocalizedString("Favorites", comment: "Favorites label"), color: .favoriteColor, icon: "heart.circle.fill")
                CompletedStat(count: sortStore.unsortedCount, label: NSLocalizedString("Skip", comment: "Skip label"), color: .skipColor, icon: "arrow.up.circle.fill")
            }
            .padding(.top, 8)
            
            // Delete button if queue is not empty
            if !state.deleteQueue.isEmpty {
                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        // Delete button (left side)
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(String(format: NSLocalizedString("Delete %d Items", comment: "Delete items button"), state.deleteQueue.count))
                                    .font(.system(size: 16, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                        
                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 24)
                        
                        // Clear queue button (right side)
                        Button {
        withAnimation(.buttonPress) {
            clearDeleteQueue()
        }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                        }
                    }
                    .background {
                        Capsule()
                            .fill(Color.deleteColor)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    }
                    .shadow(color: Color.deleteColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Text(NSLocalizedString("Cancel with X", comment: "Cancel with X message"))
                        .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 16)
            }
        }
        .padding(32)
    }
}

// MARK: - Supporting Views

@available(iOS 18.0, *)
struct StatPill: View {
    let count: Int
    let color: Color
    let icon: String
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(isSelected ? .white : color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(isSelected ? color : Color.white.opacity(0.12))
        }
        .overlay {
            if isSelected {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            }
        }
        .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
    }
}

@available(iOS 18.0, *)
struct DeleteQueuePill: View {
    let queueCount: Int
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "trash.fill")
                .font(.system(size: 9, weight: .bold))
            Text("\(queueCount)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(Color.deleteColor)
        }
        .overlay {
            Capsule()
                .strokeBorder(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: Color.deleteColor.opacity(isSelected ? 0.4 : 0.2), radius: isSelected ? 6 : 4, x: 0, y: 2)
    }
}

@available(iOS 18.0, *)
struct ProgressPill: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 3) {
            Text("\(current)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("/")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text("\(total)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .monospacedDigit()
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .glassPill()
    }
}

@available(iOS 18.0, *)
struct DateChip: View {
    let date: Date
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 10))
            Text(date.relativeString)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassPill()
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

@available(iOS 18.0, *)
struct VideoChip: View {
    let duration: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 10))
            Text(duration)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassPill()
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct StampView: View {
    let text: String
    let color: Color
    let rotation: Double
    
    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.7), radius: 12, x: 0, y: 0)  // Stronger glow for better visibility
            .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)  // Stronger outline
            .rotationEffect(.degrees(rotation))
    }
}

struct SwipeHintOverlay: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Up - Skip
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.skipColor)
                    Text(NSLocalizedString("Skip", comment: "Skip label"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.skipColor)
                }
                
                // Swipe arrows and labels
                HStack(spacing: 80) {
                    // Left - Delete
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.deleteColor)
                        Text(NSLocalizedString("Delete", comment: "Delete button"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.deleteColor)
                    }
                    
                    // Right - Keep
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.keepColor)
                        Text(NSLocalizedString("Save", comment: "Save button"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.keepColor)
                    }
                }
                
                // Double tap hint
                VStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.favoriteColor)
                    Text(NSLocalizedString("Double Tap = Favorite", comment: "Double tap hint"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 8)
                
                // Dismiss hint
                Text(NSLocalizedString("Tap to Start", comment: "Tap to start message"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss()
        }
        .transition(.opacity)
    }
}

struct CompletedStat: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 80)
    }
}

