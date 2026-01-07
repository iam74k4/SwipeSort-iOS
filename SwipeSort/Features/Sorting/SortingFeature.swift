//
//  SortingFeature.swift
//  SwipeSort
//
//  Main sorting view with integrated state management
//

import SwiftUI
import Photos

struct SortingFeature: View {
    @Bindable var photoLibrary: PhotoLibraryClient
    @Bindable var sortStore: SortResultStore
    
    @State private var state = SortingState()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundGradient
                
                if state.isComplete {
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
                    colors: [.favoriteColor.opacity(0.15), .clear],
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
        ZStack {
            // Photo card stack
            photoCardStack(in: geometry)
            
            // Swipe indicator
            SwipeOverlay(direction: state.swipeDirection, progress: state.swipeProgress)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
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
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .frame(
                        width: geometry.size.width - 48,
                        height: geometry.size.height * 0.65
                    )
                    .offset(y: 8)
                    .scaleEffect(0.95)
            }
            
            // Current photo card
            photoCard(in: geometry)
                .offset(state.offset)
                .scaleEffect(cardScale)
                .rotationEffect(.degrees(cardRotation))
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
        let cardWidth = geometry.size.width - 32
        let cardHeight = geometry.size.height * 0.65
        
        return ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
            
            // Photo content
            photoContent
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            // Action stamp overlay
            actionStamp(cardWidth: cardWidth, cardHeight: cardHeight)
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .opacity(state.imageOpacity)
        .animation(.easeOut(duration: 0.2), value: state.imageOpacity)
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
                case .up:
                    StampView(text: "♥", color: .favoriteColor, rotation: 0)
                        .position(x: cardWidth * 0.5, y: cardHeight * 0.1)
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
    private var photoContent: some View {
        if state.isLoadingImage {
            ZStack {
                Color.white.opacity(0.03)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
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
            ProgressPill(current: state.sortedCount + 1, total: state.totalCount)
        }
        .padding(.horizontal, 20)
        .padding(.top, geometry.safeAreaInsets.top + 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - Bottom Section
    
    private func bottomSection(asset: PhotoAsset, geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
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
        .padding(.horizontal, 20)
        .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
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
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
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
                } else if value.translation.height < -SwipeThreshold.detectionStart {
                    state.swipeDirection = .up
                } else {
                    state.swipeDirection = .none
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                if horizontal > SwipeThreshold.horizontal {
                    completeSwipe(direction: .right)
                } else if horizontal < -SwipeThreshold.horizontal {
                    completeSwipe(direction: .left)
                } else if vertical < -SwipeThreshold.vertical {
                    completeSwipe(direction: .up)
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
            case .up:
                state.offset = CGSize(width: 0, height: -600)
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
        case .favorite:
            HapticFeedback.notification(.success)
            // Add to iOS Favorites album
            Task {
                try? await photoLibrary.setFavorite(asset.asset, isFavorite: true)
            }
        case .unsorted:
            break
        }
        
        state.unsortedAssets.removeAll { $0.id == asset.id }
        state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
        state.updateCurrentAsset()
        
        if state.unsortedAssets.isEmpty {
            state.isComplete = true
        }
    }
    
    private func performUndo() {
        guard !state.isAnimatingOut else { return }
        
        state.offset = CGSize(width: -400, height: 0)
        state.imageOpacity = 0
        
        if let assetID = sortStore.undo() {
            if let asset = photoLibrary.allAssets.first(where: { $0.id == assetID }) {
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
        state.sortedCount = sortedIDs.count
        state.updateCurrentAsset()
        
        state.isComplete = state.unsortedAssets.isEmpty
        
        await loadCurrentImage()
    }
    
    private func loadCurrentImage() async {
        guard let asset = state.currentAsset else {
            state.currentImage = nil
            return
        }
        
        state.isLoadingImage = true
        state.imageOpacity = 0
        
        let image = await photoLibrary.loadImage(for: asset.asset, targetSize: CGSize(width: 1200, height: 1200))
        
        state.currentImage = image
        state.isLoadingImage = false
        
        withAnimation(.easeIn(duration: 0.25)) {
            state.imageOpacity = 1.0
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
                CompletedStat(count: sortStore.deleteCount, label: "削除", color: .deleteColor, icon: "trash.circle.fill")
                CompletedStat(count: sortStore.favoriteCount, label: "♥", color: .favoriteColor, icon: "heart.circle.fill")
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
            Capsule().fill(color.opacity(0.15))
        }
    }
}

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
        .background {
            Capsule().fill(.white.opacity(0.1))
        }
    }
}

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
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
}

struct StampView: View {
    let text: String
    let color: Color
    let rotation: Double
    
    var body: some View {
        Text(text)
            .font(.system(size: 32, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color, lineWidth: 4)
            }
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

