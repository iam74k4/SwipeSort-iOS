//
//  SortingFeature.swift
//  SwipeSort
//
//  Main sorting view with integrated state management
//

import SwiftUI
import Photos
import PhotosUI

@available(iOS 26.0, *)
struct SortingFeature: View {
    @Bindable var photoLibrary: PhotoLibraryClient
    @Bindable var sortStore: SortResultStore
    
    @State private var state = SortingState()
    
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
    }
    
    // MARK: - Burst Selector Overlay
    
    private var burstSelectorOverlay: some View {
        BurstSelectorView(
            burstAssets: state.burstAssets,
            photoLibrary: photoLibrary,
            onSelect: { selected, others in
                // Keep selected, mark others as delete
                sortStore.addOrUpdate(assetID: selected.id, category: .keep)
                for other in others {
                    sortStore.addOrUpdate(assetID: other.id, category: .delete)
                }
                
                // Remove all burst photos from unsorted
                let burstIDs = Set(state.burstAssets.map { $0.id })
                state.unsortedAssets.removeAll { burstIDs.contains($0.id) }
                state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
                state.updateCurrentAsset()
                state.resetBurstSelector()
                
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
                    sortStore.addOrUpdate(assetID: asset.id, category: .keep)
                }
                
                // Remove all burst photos from unsorted
                let burstIDs = Set(state.burstAssets.map { $0.id })
                state.unsortedAssets.removeAll { burstIDs.contains($0.id) }
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
            case .none:
                Color.clear
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Photo Viewer Content
    
    private func photoViewerContent(for asset: PhotoAsset, in geometry: GeometryProxy) -> some View {
        ZStack {
            // Photo card stack
            photoCardStack(in: geometry)
            
            // Swipe indicator
            SwipeOverlay(direction: state.swipeDirection, progress: state.swipeProgress)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // Heart animation for double tap
            if state.showHeartAnimation {
                HeartAnimationView(isAnimating: $state.showHeartAnimation)
            }
            
            // UI Chrome
            VStack(spacing: 0) {
                topBar(asset: asset, geometry: geometry)
                
                Spacer()
                
                bottomSection(asset: asset, geometry: geometry)
            }
        }
    }
    
    // MARK: - Photo Card Stack
    
    private func photoCardStack(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Next card preview (behind)
            if state.unsortedAssets.count > 1 {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .frame(
                        width: geometry.size.width - 24,
                        height: geometry.size.height * 0.78
                    )
                    .offset(y: 6)
                    .scaleEffect(0.97)
            }
            
            // Current photo card
            photoCard(in: geometry)
                .offset(state.offset)
                .scaleEffect(cardScale)
                .rotationEffect(.degrees(cardRotation))
                .onTapGesture(count: 2) {
                    performFavorite()
                }
                .gesture(dragGesture)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state.offset)
    }
    
    private var cardScale: CGFloat {
        state.isAnimatingOut ? 1.0 : 1.0 - abs(state.offset.width) / 3000
    }
    
    private var cardRotation: Double {
        Double(state.offset.width) / 25
    }
    
    private func photoCard(in geometry: GeometryProxy) -> some View {
        let cardWidth = geometry.size.width - 16
        let cardHeight = geometry.size.height * 0.78
        
        return ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
            
            // Photo content (Live Photo or regular)
            photoContentView
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
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
            if let asset = state.currentAsset, asset.isLivePhoto {
                state.isLongPressing = pressing
                if pressing && state.currentLivePhoto != nil {
                    state.isPlayingLivePhoto = true
                    HapticFeedback.impact(.light)
                } else {
                    state.isPlayingLivePhoto = false
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
                        .position(x: cardWidth * 0.2, y: cardHeight * 0.1)
                case .left:
                    StampView(text: "DELETE", color: .deleteColor, rotation: 15)
                        .position(x: cardWidth * 0.8, y: cardHeight * 0.1)
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
                Color.white.opacity(0.03)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        } else if state.isPlayingLivePhoto, let livePhoto = state.currentLivePhoto {
            // Live Photo playback
            LivePhotoPlayerView(livePhoto: livePhoto, isPlaying: $state.isPlayingLivePhoto)
        } else if let image = state.currentImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.white.opacity(0.03)
                Image(systemName: "photo")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }
    
    // MARK: - Top Bar
    
    private func topBar(asset: PhotoAsset, geometry: GeometryProxy) -> some View {
        HStack(spacing: 12) {
            // Stats
            HStack(spacing: 6) {
                StatPill(count: sortStore.keepCount, color: .keepColor, icon: "checkmark")
                StatPill(count: sortStore.deleteCount, color: .deleteColor, icon: "trash")
                StatPill(count: sortStore.favoriteCount, color: .favoriteColor, icon: "heart.fill")
            }
            
            Spacer()
            
            // Progress
            ProgressPill(current: sortStore.totalSortedCount + 1, total: state.totalCount)
        }
        .padding(.horizontal, 12)
        .padding(.top, geometry.safeAreaInsets.top + 4)
        .padding(.bottom, 8)
    }
    
    // MARK: - Bottom Section
    
    private func bottomSection(asset: PhotoAsset, geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // Video indicator
            if asset.isVideo {
                VideoChip(duration: asset.formattedDuration)
            }
            
            // Undo button
            if sortStore.canUndo {
                undoButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, geometry.safeAreaInsets.bottom + 12)
        .animation(.spring(response: 0.35), value: sortStore.canUndo)
    }
    
    // MARK: - Undo Button
    
    private var undoButton: some View {
        Button {
            performUndo()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .semibold))
                Text("戻す")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassPill()
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                state.offset = value.translation
                
                if value.translation.width > SwipeThreshold.detectionStart {
                    state.swipeDirection = .right
                } else if value.translation.width < -SwipeThreshold.detectionStart {
                    state.swipeDirection = .left
                } else {
                    state.swipeDirection = .none
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                
                if horizontal > SwipeThreshold.horizontal {
                    completeSwipe(direction: .right)
                } else if horizontal < -SwipeThreshold.horizontal {
                    completeSwipe(direction: .left)
                } else {
                    resetPosition()
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
            case .none:
                break
            }
            state.imageOpacity = 0
        }
        
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            processSort(direction: direction)
            
            if let next = state.nextImage {
                state.currentImage = next
                state.nextImage = nil
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
    
    private func processSort(direction: SwipeDirection) {
        guard let asset = state.currentAsset else { return }
        
        let category = direction.category
        sortStore.addOrUpdate(assetID: asset.id, category: category)
        
        switch category {
        case .keep:
            HapticFeedback.impact(.medium)
        case .delete:
            HapticFeedback.impact(.heavy)
        case .favorite, .unsorted:
            break
        }
        
        state.unsortedAssets.removeAll { $0.id == asset.id }
        state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
        state.updateCurrentAsset()
        
        if state.unsortedAssets.isEmpty {
            state.isComplete = true
        }
    }
    
    private func performFavorite() {
        guard let asset = state.currentAsset, !state.isAnimatingOut else { return }
        
        // Show heart animation
        state.showHeartAnimation = true
        HapticFeedback.notification(.success)
        
        // Add to favorites
        sortStore.addOrUpdate(assetID: asset.id, category: .favorite)
        
        // Add to iOS Favorites album
        Task {
            try? await photoLibrary.setFavorite(asset.asset, isFavorite: true)
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
            
            // Move to next
            state.unsortedAssets.removeAll { $0.id == asset.id }
            state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
            state.updateCurrentAsset()
            
            if state.unsortedAssets.isEmpty {
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
    
    private func performUndo() {
        guard !state.isAnimatingOut else { return }
        
        state.offset = CGSize(width: -400, height: 0)
        state.imageOpacity = 0
        
        if let assetID = sortStore.undo() {
            if let asset = photoLibrary.allAssets.first(where: { $0.id == assetID }) {
                // If the undone action was a favorite, remove from iOS Favorites
                if asset.asset.isFavorite {
                    Task {
                        try? await photoLibrary.setFavorite(asset.asset, isFavorite: false)
                    }
                }
                
                state.unsortedAssets.insert(asset, at: 0)
                state.currentIndex = 0
                state.updateCurrentAsset()
                state.isComplete = false
            }
        }
        
        Task { await loadCurrentImage() }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            state.offset = .zero
            state.imageOpacity = 1.0
        }
        
        HapticFeedback.impact(.light)
    }
    
    private func resetPosition() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.offset = .zero
            state.swipeDirection = .none
            state.imageOpacity = 1.0
        }
    }
    
    // MARK: - Loading
    
    private func loadAssets() async {
        let allAssets = await photoLibrary.fetchAllAssets()
        let sortedIDs = sortStore.sortedIDs
        
        state.unsortedAssets = allAssets.filter { !sortedIDs.contains($0.id) }
        state.totalCount = allAssets.count
        state.updateCurrentAsset()
        
        state.isComplete = state.unsortedAssets.isEmpty
        
        await loadCurrentImage()
    }
    
    private func loadCurrentImage() async {
        guard let asset = state.currentAsset else {
            state.currentImage = nil
            state.currentLivePhoto = nil
            state.currentBurstCount = nil
            return
        }
        
        state.isLoadingImage = true
        state.imageOpacity = 0
        
        // Load main image (use fast preview for RAW images)
        let image = await photoLibrary.loadImage(
            for: asset.asset,
            targetSize: CGSize(width: 1200, height: 1200),
            preferFastPreview: asset.isRAW
        )
        
        state.currentImage = image
        state.isLoadingImage = false
        
        withAnimation(.easeIn(duration: 0.25)) {
            state.imageOpacity = 1.0
        }
        
        // Load Live Photo if applicable
        if asset.isLivePhoto {
            let livePhoto = await photoLibrary.loadLivePhoto(for: asset.asset, targetSize: CGSize(width: 1200, height: 1200))
            state.currentLivePhoto = livePhoto
        } else {
            state.currentLivePhoto = nil
        }
        
        // Get burst count if applicable
        if let burstId = asset.burstIdentifier {
            let burstAssets = photoLibrary.fetchBurstAssets(for: burstId)
            state.currentBurstCount = burstAssets.count
        } else {
            state.currentBurstCount = nil
        }
        
        photoLibrary.updateCacheWindow(currentIndex: state.currentIndex, assets: state.unsortedAssets)
        
        await preloadNextImage()
    }
    
    private func preloadNextImage() async {
        let nextIndex = state.currentIndex + 1
        guard nextIndex < state.unsortedAssets.count else {
            state.nextImage = nil
            return
        }
        
        let nextAsset = state.unsortedAssets[nextIndex]
        state.nextImage = await photoLibrary.loadImage(for: nextAsset.asset, targetSize: CGSize(width: 1200, height: 1200))
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
            
            Text("写真を読み込み中...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                Text("写真がありません")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("フォトライブラリに写真を追加してください")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
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
                Text("整理完了!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("すべての写真を整理しました")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Stats
            HStack(spacing: 24) {
                CompletedStat(count: sortStore.keepCount, label: "Keep", color: .keepColor, icon: "checkmark.circle.fill")
                CompletedStat(count: sortStore.deleteCount, label: "削除候補", color: .deleteColor, icon: "trash.circle.fill")
                CompletedStat(count: sortStore.favoriteCount, label: "お気に入り", color: .favoriteColor, icon: "heart.circle.fill")
            }
            .padding(.top, 8)
            
            // Hint
            Text("「確認」タブで削除候補を確認・削除できます")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 16)
        }
        .padding(32)
    }
}

// MARK: - Supporting Views

@available(iOS 26.0, *)
struct StatPill: View {
    let count: Int
    let color: Color
    let icon: String
    
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

@available(iOS 26.0, *)
struct ProgressPill: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(current)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("/")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text("\(total)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassPill()
    }
}

@available(iOS 26.0, *)
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
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
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
            .shadow(color: color.opacity(0.5), radius: 8, x: 0, y: 0)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .rotationEffect(.degrees(rotation))
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

