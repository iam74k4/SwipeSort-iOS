//
//  SortingFeature.swift
//  Sift
//
//  Main sorting view with integrated state management
//

import SwiftUI
@preconcurrency import Photos
import UIKit
import os

private let logger = Logger(subsystem: "com.sift", category: "SortingFeature")

@available(iOS 18.0, *)
struct SortingFeature: View {
    @Bindable var photoLibrary: PhotoLibraryClient
    @Bindable var sortStore: SortResultStore
    
    @State private var state = SortingState()

    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showSwipeHint = false
    @State private var showAlbumView = false
    @State private var albumViewCategory: SortCategory? = nil
    @State private var hasLoadedAssets = false
    @State private var showNoMatchToast = false
    @State private var showDateRangePicker = false
    @State private var dateRangeStart: Date = Date()
    @State private var dateRangeEnd: Date = Date()
    
    // Task management
    @State private var imageLoadTask: Task<Void, Never>?
    
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
                } else if !hasLoadedAssets || photoLibrary.isLoading {
                    // Show loading while initial load is in progress
                    loadingView
                } else {
                    emptyView
                }
                
                // "No matches" toast
                if showNoMatchToast {
                    VStack {
                        Spacer()
                        HStack(spacing: ThemeLayout.paddingSmall) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.themeBody)
                            Text(NSLocalizedString("No Matching Photos", comment: "No matching photos message"))
                                .font(.themeBody)
                        }
                        .foregroundStyle(Color.themePrimary)
                        .padding(.horizontal, ThemeLayout.spacingItem)
                        .padding(.vertical, ThemeLayout.spacingMediumLarge)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + ThemeLayout.toastBottomPadding)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task {
            guard !hasLoadedAssets else { return }
            hasLoadedAssets = true
            await loadAssets()
        }
        .onDisappear {
            imageLoadTask?.cancel()
            imageLoadTask = nil
        }
        .alert(NSLocalizedString("Delete Failed", comment: "Delete failed alert title"), isPresented: $showDeleteError) {
            Button(NSLocalizedString("OK", comment: "OK button")) {}
        } message: {
            Text(deleteErrorMessage)
        }
        .sheet(isPresented: $showAlbumView) {
            if let category = albumViewCategory {
                AlbumView(
                    category: category,
                    photoLibrary: photoLibrary,
                    sortStore: sortStore
                )
            }
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
        .sheet(isPresented: $showDateRangePicker) {
            DateRangePickerView(
                startDate: $dateRangeStart,
                endDate: $dateRangeEnd,
                onApply: {
                    applyDateRangeFilterWithAutoReset(start: dateRangeStart, end: dateRangeEnd)
                }
            )
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
                
                // Remove selected photo from list
                state.removeAsset(selected)
                
                // Add other photos to delete queue
                for other in others {
                    let otherPreviousCategory = sortStore.category(for: other.id)
                    // Create undo record (record that it was added to delete queue)
                    sortStore.createUndoRecord(assetID: other.id, previousCategory: otherPreviousCategory)
                    // Just add to delete queue (don't record as delete category until actually deleted)
                    state.deleteQueue.append(other)
                    state.removeAsset(other)
                }
                
                advanceAfterSortingAction()
                state.resetBurstSelector()
                if !state.unsortedAssets.isEmpty {
                    scheduleImageLoad()
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
                
                advanceAfterSortingAction()
                state.resetBurstSelector()
                if !state.unsortedAssets.isEmpty {
                    scheduleImageLoad()
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
                    endRadius: CardAnimation.glowEndRadius
                )
                .animation(.easeOut(duration: TimingConstants.durationNormal), value: state.swipeDirection)
            case .left:
                RadialGradient(
                    colors: [.deleteColor.opacity(0.15), .clear],
                    center: .leading,
                    startRadius: 0,
                    endRadius: CardAnimation.glowEndRadius
                )
                .animation(.easeOut(duration: TimingConstants.durationNormal), value: state.swipeDirection)
            case .none:
                Color.clear
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Photo Viewer Content
    
    private func photoViewerContent(for asset: PhotoAsset, in geometry: GeometryProxy) -> some View {
        // Card area full-screen so swiped image stays visible under transparent bars
        ZStack {
            ZStack {
                photoCardStack(in: geometry)
                SwipeOverlay(direction: state.swipeDirection, progress: state.swipeProgress)
                    .allowsHitTesting(false)
                HeartAnimationView(isAnimating: $state.showHeartAnimation)
                if showSwipeHint {
                    SwipeHintOverlay {
                        withAnimation(.easeOut(duration: TimingConstants.durationNormal)) {
                            showSwipeHint = false
                            hasSeenSwipeHint = true
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating bars (transparent overlay style)
            VStack(spacing: 0) {
                topBar(asset: asset, geometry: geometry)
                    .padding(.horizontal, ThemeLayout.paddingFloating)
                    .padding(.top, geometry.safeAreaInsets.top)
                Spacer(minLength: 0)
                bottomSection(asset: asset, geometry: geometry)
                    .padding(.horizontal, ThemeLayout.paddingFloating)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + ThemeLayout.spacingSmall)
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Photo Card Stack
    
    private func photoCardStack(in geometry: GeometryProxy) -> some View {
        GeometryReader { cardGeometry in
            let cardWidth = cardGeometry.size.width - CardAnimation.cardDimensionOffset
            let cardHeight = cardGeometry.size.height - CardAnimation.cardDimensionOffset
            
            ZStack {
                // Next card preview (behind) - uses app background to blend seamlessly
                if state.unsortedAssets.count > 1 {
                    RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                        .fill(Color.appBackground)
                        .frame(width: cardWidth, height: cardHeight)
                        .offset(y: CardAnimation.nextCardOffset)
                        .scaleEffect(CardAnimation.dragScale)
                }
                
                // Current photo card
                photoCard(width: cardWidth, height: cardHeight)
                    .offset(state.offset)
                    .scaleEffect(cardScale, anchor: .center)
                    .rotationEffect(.degrees(cardRotation))
                    .accessibilityLabel(NSLocalizedString("Photo Card", comment: "Photo Card"))
                    .accessibilityHint(NSLocalizedString("Photo Card Hint", comment: "Photo Card Hint"))
                    .accessibilityAddTraits(.isButton)
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
        return 1.0 - abs(state.offset.width) / CardAnimation.scaleDivisor
    }
    
    private var cardRotation: Double {
        Double(state.offset.width) / CardAnimation.rotationDivisor
    }
    
    private func photoCard(width cardWidth: CGFloat, height cardHeight: CGFloat) -> some View {
        ZStack {
            // Card background (matches app background to hide Aspect Fit padding)
            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                .fill(Color.appBackground)
            
            // Photo content (Live Photo or regular)
            photoContentView
                .clipShape(RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous))
            
            // Media type badges (top-left)
            if let asset = state.currentAsset {
                mediaBadges(for: asset)
            }
            
            // Action stamp overlay
            actionStamp(cardWidth: cardWidth, cardHeight: cardHeight)
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: .black.opacity(ThemeLayout.shadowOpacityCard), radius: ThemeLayout.shadowRadiusCard, x: 0, y: ThemeLayout.shadowYCard)
        .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySubtle), radius: ThemeLayout.shadowRadiusTiny, x: 0, y: ThemeLayout.shadowYTiny)
        .opacity(state.imageOpacity)
        .animation(.easeOut(duration: TimingConstants.durationNormal), value: state.imageOpacity)
        .onTapGesture {
            guard let asset = state.currentAsset, asset.isVideo else { return }
            // Toggle video play/stop
            if state.isPlayingVideo {
                state.isPlayingVideo = false
                state.isVideoPaused = false
                state.videoCurrentTime = 0
                state.videoDuration = 0
            } else {
                state.isPlayingVideo = true
                state.isVideoPaused = false
                HapticFeedback.impact(.light)
            }
        }
        .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
            guard let asset = state.currentAsset else { return }
            state.isLongPressing = pressing

            // Long press to play Live Photo only
            if asset.isLivePhoto {
                if pressing && state.currentLivePhoto != nil {
                    state.isPlayingLivePhoto = true
                    HapticFeedback.impact(.light)
                } else {
                    state.isPlayingLivePhoto = false
                }
            }
        }, perform: {})
        .accessibilityHint(state.currentAsset?.isVideo == true
            ? NSLocalizedString("Tap to Play", comment: "Tap to Play video")
            : NSLocalizedString("Long Press to Play", comment: "Long Press to Play"))
    }
    
    // MARK: - Media Badges
    
    @ViewBuilder
    private func mediaBadges(for asset: PhotoAsset) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: ThemeLayout.spacingCompact) {
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
                .padding(ThemeLayout.spacingItem)
                Spacer()
            }
            Spacer()
        }
    }
    
    private func openBurstSelector(for asset: PhotoAsset) {
        guard let burstId = asset.burstIdentifier else { return }
        
        state.burstAssets = photoLibrary.fetchBurstAssets(for: burstId)
        if state.burstAssets.count > 1 {
            withAnimation(.easeInOut(duration: TimingConstants.durationSlow)) {
                state.showingBurstSelector = true
            }
        }
    }
    
    // MARK: - Action Stamp
    
    @ViewBuilder
    private func actionStamp(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let progress = state.swipeProgress
        
        if progress > CardAnimation.stampThreshold {
            Group {
                switch state.swipeDirection {
                case .right:
                    StampView(text: NSLocalizedString("KEEP", comment: "Keep stamp"), color: .keepColor, rotation: -CardAnimation.stampRotation)
                        .position(x: cardWidth * CardAnimation.stampPositionX, y: cardHeight * CardAnimation.stampPositionY)
                case .left:
                    StampView(text: NSLocalizedString("DELETE", comment: "Delete stamp"), color: .deleteColor, rotation: CardAnimation.stampRotation)
                        .position(x: cardWidth * (1 - CardAnimation.stampPositionX), y: cardHeight * CardAnimation.stampPositionY)
                case .none:
                    EmptyView()
                }
            }
            .opacity(min((progress - CardAnimation.stampThreshold) * 2, 1.0))
            .scaleEffect(CardAnimation.stampScaleBase + min((progress - CardAnimation.stampThreshold), CardAnimation.stampScaleMax))
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
                    .scaleEffect(ThemeLayout.scaleLoading)
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
                VideoPlayerView(
                    asset: asset.asset,
                    isPlaying: $state.isPlayingVideo,
                    isPaused: $state.isVideoPaused,
                    isSeeking: $state.isSeeking,
                    currentTime: $state.videoCurrentTime,
                    duration: $state.videoDuration
                )
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
                    .font(.themeDisplayXLarge)
                    .foregroundStyle(Color.themeTertiary)
            }
        }
    }
    
    // MARK: - Top Bar
    
    private func topBar(asset: PhotoAsset, geometry: GeometryProxy) -> some View {
        HStack(spacing: ThemeLayout.spacingCompact) {
            // Filter button (with max width to prevent overflow)
            filterButton
                .layoutPriority(0)
            
            // Stats (tappable for filtering) - flexible width
            HStack(spacing: ThemeLayout.spacingXXSmall) {
                Button {
                    withAnimation(.overlayFade) {
                        applyCategoryFilterWithAutoReset(state.selectedCategoryFilter == .keep ? nil : .keep)
                    }
                    scheduleImageLoad()
                } label: {
                    StatPill(
                        count: sortStore.keepCount,
                        color: .keepColor,
                        icon: "checkmark",
                        isSelected: state.selectedCategoryFilter == .keep
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(format: NSLocalizedString("Keep Count", comment: "Keep Count"), sortStore.keepCount))
                .accessibilityHint(NSLocalizedString("Keep Count Hint", comment: "Keep Count Hint"))
                
                // Delete count (deleted + queue total)
                Button {
                    withAnimation(.overlayFade) {
                        applyCategoryFilterWithAutoReset(state.selectedCategoryFilter == .delete ? nil : .delete)
                    }
                    scheduleImageLoad()
                } label: {
                    StatPill(
                        count: sortStore.deleteCount + state.deleteQueue.count,
                        color: .deleteColor,
                        icon: "trash",
                        isSelected: state.selectedCategoryFilter == .delete
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(format: NSLocalizedString("Delete Count", comment: "Delete Count"), sortStore.deleteCount + state.deleteQueue.count))
                .accessibilityHint(NSLocalizedString("Delete Count Hint", comment: "Delete Count Hint"))
                
                Button {
                    withAnimation(.overlayFade) {
                        applyCategoryFilterWithAutoReset(state.selectedCategoryFilter == .favorite ? nil : .favorite)
                    }
                    scheduleImageLoad()
                } label: {
                    StatPill(
                        count: sortStore.favoriteCount,
                        color: .favoriteColor,
                        icon: "heart.fill",
                        isSelected: state.selectedCategoryFilter == .favorite
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(format: NSLocalizedString("Favorite Count", comment: "Favorite Count"), sortStore.favoriteCount))
                .accessibilityHint(NSLocalizedString("Favorite Count Hint", comment: "Favorite Count Hint"))
            }
            .layoutPriority(1)
            
            Spacer(minLength: ThemeLayout.spacingCompact)
            
            // Progress (category filter shows list position, otherwise shows sort progress)
            // Delete queue assets are counted as sorted
            // Only add +1 for current asset if there are unsorted assets remaining
            ProgressPill(
                current: state.selectedCategoryFilter != nil
                    ? min(state.currentIndex + 1, state.unsortedAssets.count)
                    : sortStore.totalSortedCount + state.deleteQueue.count + (state.currentAsset != nil ? 1 : 0),
                total: state.selectedCategoryFilter != nil
                    ? state.unsortedAssets.count
                    : state.totalCount
            )
            .layoutPriority(1)
            .accessibilityLabel(String(format: NSLocalizedString("Progress %d of %d", comment: "Progress accessibility"),
                state.selectedCategoryFilter != nil ? min(state.currentIndex + 1, state.unsortedAssets.count) : sortStore.totalSortedCount + state.deleteQueue.count + (state.currentAsset != nil ? 1 : 0),
                state.selectedCategoryFilter != nil ? state.unsortedAssets.count : state.totalCount))
        }
        .padding(.horizontal, ThemeLayout.spacingMedium)
        .padding(.vertical, ThemeLayout.paddingSmall)
    }
    
    // MARK: - Filter Button
    
    private var filterButton: some View {
        Menu {
            ForEach(MediaFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.overlayFade) {
                        applyMediaFilterWithAutoReset(filter)
                    }
                    scheduleImageLoad()
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
            HStack(spacing: ThemeLayout.spacingXXSmall) {
                Image(systemName: state.currentFilter.icon)
                    .font(.themeButtonSmall)
                if state.currentFilter != .all {
                    Text(state.currentFilter.localizedName)
                        .font(.themeButtonSmall)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .foregroundStyle(state.currentFilter == .all ? Color.themePrimary : Color.themeSecondary)
            .padding(.horizontal, ThemeLayout.spacingMedium)
            .padding(.vertical, ThemeLayout.spacingSmall)
            .frame(maxWidth: state.currentFilter == .all ? nil : 100)
            .background {
                RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                    .fill(Color.black.opacity(ThemeLayout.opacityHeavy))
            }
            .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
        }
        .id(state.currentFilter) // Recreate view on filter change to stabilize layout
        .accessibilityLabel(NSLocalizedString("Filter Photos", comment: "Filter Photos"))
        .accessibilityHint(NSLocalizedString("Filter Photos Hint", comment: "Filter Photos Hint"))
    }
    
    // MARK: - Bottom Section
    
    private func bottomSection(asset: PhotoAsset, geometry: GeometryProxy) -> some View {
        VStack(spacing: ThemeLayout.spacingSmall) {
            // Video seek bar (only when playing video)
            if state.isPlayingVideo && state.videoDuration > 0 {
                videoSeekBar
            }
            
            HStack(alignment: .center) {
                // Left side: Media info chips
                HStack(spacing: ThemeLayout.spacingSmall) {
                    // Sort order button
                    sortOrderButton
                    
                    if let date = asset.creationDate {
                        HStack(spacing: ThemeLayout.spacingXXSmall) {
                            Button {
                                dateRangeStart = date
                                dateRangeEnd = date
                                showDateRangePicker = true
                            } label: {
                                DatePill(date: date, isFiltered: state.hasDateFilter)
                            }
                            .buttonStyle(.plain)
                            
                            // Clear filter button (only when filtered)
                            if state.hasDateFilter {
                                Button {
                                    withAnimation(.overlayFade) {
                                        state.clearDateFilter(sortStore: sortStore)
                                    }
                                    scheduleImageLoad()
                                    HapticFeedback.selection()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.themeButton)
                                        .foregroundStyle(Color.themeSecondary)
                                        .frame(width: ThemeLayout.buttonSizeMedium, height: ThemeLayout.buttonSizeMedium)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if asset.isVideo && !state.isPlayingVideo {
                        VideoPill(duration: asset.formattedDuration)
                    }
                }
                
                Spacer(minLength: ThemeLayout.spacingSmall)
                
                // Right side: Action buttons
                HStack(spacing: ThemeLayout.paddingSmall) {
                    if sortStore.canUndo {
                        undoButton
                    }
                    if !state.deleteQueue.isEmpty {
                        deleteQueueButton
                    }
                }
            }
            .frame(minHeight: ThemeLayout.buttonSizeMedium)
        }
        .padding(.horizontal, ThemeLayout.spacingMedium)
        .padding(.vertical, ThemeLayout.paddingSmall)
        .animation(.easeInOut(duration: TimingConstants.durationNormal), value: sortStore.canUndo)
        .animation(.easeInOut(duration: TimingConstants.durationNormal), value: state.deleteQueue.count)
    }
    
    // MARK: - Video Seek Bar
    
    private var videoSeekBar: some View {
        HStack(spacing: ThemeLayout.spacingMedium) {
            // Play/Pause button
            Button {
                state.isVideoPaused.toggle()
            } label: {
                Image(systemName: state.isVideoPaused ? "play.fill" : "pause.fill")
                    .font(.themeButton)
                    .foregroundStyle(Color.themePrimary)
            }
            
            // Current time
            Text(formatVideoTime(state.videoCurrentTime))
                .font(.themeCaption)
                .monospacedDigit()
                .foregroundStyle(Color.themePrimary)
                .frame(width: ThemeLayout.videoTimeLabelWidth, alignment: .trailing)
            
            // Seek slider
            Slider(
                value: Binding(
                    get: { state.videoCurrentTime },
                    set: { newValue in
                        state.videoCurrentTime = newValue
                    }
                ),
                in: 0...max(state.videoDuration, 0.01),
                onEditingChanged: { editing in
                    state.isSeeking = editing
                    if !editing {
                        // Notify on seek completion
                        NotificationCenter.default.post(
                            name: .videoSeekRequested,
                            object: nil,
                            userInfo: ["time": state.videoCurrentTime]
                        )
                    }
                }
            )
            .tint(Color.keepColor)
            
            // Total duration
            Text(formatVideoTime(state.videoDuration))
                .font(.themeCaption)
                .monospacedDigit()
                .foregroundStyle(Color.themeSecondary)
                .frame(width: ThemeLayout.videoTimeLabelWidth, alignment: .leading)
        }
        .padding(.horizontal, ThemeLayout.spacingSmall)
        .padding(.vertical, ThemeLayout.spacingSmall)
        .background(Color.black.opacity(ThemeLayout.opacityHeavy))
        .clipShape(RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous))
        .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
    }
    
    /// Format seconds to mm:ss or h:mm:ss
    private func formatVideoTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    // MARK: - Sort Order Button
    
    private var sortOrderButton: some View {
        Button {
            withAnimation(.overlayFade) {
                state.toggleSortOrder(sortStore: sortStore)
            }
            scheduleImageLoad()
            HapticFeedback.selection()
        } label: {
            Image(systemName: state.sortOrder.icon)
                .font(.themeButton)
                .foregroundStyle(Color.themePrimary)
                .frame(width: ThemeLayout.buttonSizeMedium, height: ThemeLayout.buttonSizeMedium)
                .background(Color.black.opacity(ThemeLayout.opacityHeavy))
                .clipShape(RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusCard, style: .continuous))
                .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.sortOrder.localizedName)
        .accessibilityHint(NSLocalizedString("Toggle Sort Order", comment: "Toggle sort order hint"))
    }
    
    // MARK: - Undo Button
    
    private var undoButton: some View {
        Button {
            Task {
                await performUndo()
            }
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.themeButton)
                .foregroundStyle(Color.themePrimary)
                .frame(width: ThemeLayout.buttonSizeMedium, height: ThemeLayout.buttonSizeMedium)
                .background(Color.black.opacity(ThemeLayout.opacityHeavy))
                .clipShape(RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusCard, style: .continuous))
                .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
        }
        .disabled(state.isUndoing || !sortStore.canUndo)
        .opacity((state.isUndoing || !sortStore.canUndo) ? 0.5 : 1.0)
        .accessibilityLabel(NSLocalizedString("Undo Last Action", comment: "Undo Last Action"))
        .accessibilityHint(NSLocalizedString("Undo Last Action Hint", comment: "Undo Last Action Hint"))
    }
    
    // MARK: - Delete Queue Button
    
    private var deleteQueueButton: some View {
        HStack(spacing: 0) {
            // Delete button (left side)
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: ThemeLayout.spacingSmall) {
                    Image(systemName: "trash.fill")
                        .font(.themeButton)
                    Text("\(state.deleteQueue.count)")
                        .font(.themeButton)
                        .monospacedDigit()
                }
                .foregroundStyle(Color.deleteColor)
                .padding(.horizontal, ThemeLayout.spacingMediumLarge)
            }
            .accessibilityLabel(NSLocalizedString("Delete Queued Photos", comment: "Delete Queued Photos"))
            .accessibilityHint(NSLocalizedString("Delete Queued Photos Hint", comment: "Delete Queued Photos Hint"))
            
            // Divider
            Rectangle()
                .fill(Color.themeTertiary)
                .frame(width: ThemeLayout.lineWidthThin, height: ThemeLayout.dividerHeight)
            
            // Clear queue button (right side)
            Button {
                withAnimation(.buttonPress) {
                    clearDeleteQueue()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.themeButtonSmall)
                    .foregroundStyle(Color.themeSecondary)
                    .padding(.horizontal, ThemeLayout.spacingMediumLarge)
            }
            .accessibilityLabel(NSLocalizedString("Clear Delete Queue", comment: "Clear Delete Queue"))
            .accessibilityHint(NSLocalizedString("Clear Delete Queue Hint", comment: "Clear Delete Queue Hint"))
        }
        .frame(height: ThemeLayout.buttonSizeMedium)
        .background(Color.black.opacity(ThemeLayout.opacityHeavy))
        .clipShape(RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusCard, style: .continuous))
        .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
    }
    
    private func clearDeleteQueue() {
        // Clear delete queue and restore assets to unsorted
        for asset in state.deleteQueue {
            // Remove delete record (if exists)
            sortStore.remove(assetID: asset.id)
            // Also remove undo record
            sortStore.removeUndoRecord(for: asset.id)
            
            state.restoreAssetToUnsorted(asset, atStart: false)
        }
        state.deleteQueue.removeAll()
        state.isComplete = false
        
        // Update current asset
        state.currentIndex = 0
        state.updateCurrentAsset()
        
        scheduleImageLoad()
        
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
                    // Vertical swipe not supported
                    state.swipeDirection = .none
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
                    // Vertical swipe not supported
                    resetPosition()
                }
            }
    }
    
    // MARK: - Filter Actions
    
    /// Apply category filter with auto-reset if no matches
    private func applyCategoryFilterWithAutoReset(_ category: SortCategory?) {
        let previousFilter = state.selectedCategoryFilter
        state.applyCategoryFilter(category, sortStore: sortStore)
        
        // Auto-reset filter if no matches after applying
        if category != nil && state.unsortedAssets.isEmpty {
            state.applyCategoryFilter(nil, sortStore: sortStore)
            showNoMatchToastBriefly()
            HapticFeedback.notification(.warning)
        } else if previousFilter != category {
            HapticFeedback.selection()
        }
    }
    
    /// Apply media filter with auto-reset if no matches
    private func applyMediaFilterWithAutoReset(_ filter: MediaFilter) {
        let previousFilter = state.currentFilter
        state.applyFilter(filter, sortStore: sortStore)
        
        // Auto-reset filter if no matches after applying
        if filter != .all && state.unsortedAssets.isEmpty {
            state.applyFilter(.all, sortStore: sortStore)
            showNoMatchToastBriefly()
            HapticFeedback.notification(.warning)
        } else if previousFilter != filter {
            HapticFeedback.selection()
        }
    }
    
    /// Apply date range filter with auto-reset if no matches
    private func applyDateRangeFilterWithAutoReset(start: Date, end: Date) {
        withAnimation(.overlayFade) {
            state.setDateRangeFilter(start: start, end: end, sortStore: sortStore)
        }
        
        // Auto-reset filter if no matches after applying
        if state.unsortedAssets.isEmpty {
            withAnimation(.overlayFade) {
                state.clearDateFilter(sortStore: sortStore)
            }
            showNoMatchToastBriefly()
            HapticFeedback.notification(.warning)
        } else {
            scheduleImageLoad()
            HapticFeedback.selection()
        }
    }
    
    /// Show "no matches" toast briefly
    private func showNoMatchToastBriefly() {
        withAnimation(.easeOut(duration: TimingConstants.durationNormal)) {
            showNoMatchToast = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(TimingConstants.toastDuration))
            withAnimation(.easeOut(duration: TimingConstants.durationNormal)) {
                showNoMatchToast = false
            }
        }
    }
    
    // MARK: - Actions
    
    /// Update state to advance to next asset after sort/favorite/burst selection.
    private func advanceAfterSortingAction() {
        state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
        state.updateCurrentAsset()
        // Complete only when unsorted assets and delete queue are both empty
        if state.allUnsortedAssets.isEmpty && state.deleteQueue.isEmpty {
            state.isComplete = true
        }
    }
    
    private func completeSwipe(direction: SwipeDirection) {
        guard direction != .none, !state.isAnimatingOut else { return }
        // Capture asset at swipe start (prevent currentAsset from changing due to filter changes)
        guard let assetToSort = state.currentAsset else { return }
        
        // Reset heart animation when starting swipe animation
        state.showHeartAnimation = false
        
        state.isAnimatingOut = true
        
        Task { await preloadNextImage() }
        
        withAnimation(.easeOut(duration: TimingConstants.durationSlow)) {
            switch direction {
            case .right:
                state.offset = CGSize(width: CardAnimation.swipeOutOffset, height: CardAnimation.swipeOutVerticalOffset)
            case .left:
                state.offset = CGSize(width: -CardAnimation.swipeOutOffset, height: CardAnimation.swipeOutVerticalOffset)
            case .none:
                break
            }
            state.imageOpacity = 0
        }
        
        Task {
            try? await Task.sleep(for: .milliseconds(TimingConstants.sleepMedium))
            
            await processSort(asset: assetToSort, direction: direction)
            
            // Clear old image before loading next
            state.currentImage = nil
            state.currentLivePhoto = nil
            
            // Load next image (use nextImage if already loaded)
            if let next = state.nextImage {
                state.currentImage = next
                state.nextImage = nil
            } else {
                // Load current asset image if nextImage is not loaded
                await loadCurrentImage()
            }
            
            state.offset = .zero
            state.swipeDirection = .none
            state.isAnimatingOut = false
            
            state.imageOpacity = 0
            withAnimation(.easeIn(duration: TimingConstants.durationNormal)) {
                state.imageOpacity = 1.0
            }
        }
    }
    
    private func processSort(asset: PhotoAsset, direction: SwipeDirection) async {
        switch direction {
        case .right:
            let previousCategory = sortStore.category(for: asset.id)
            sortStore.addOrUpdate(assetID: asset.id, category: .keep, previousCategory: previousCategory, recordUndo: true)
            HapticFeedback.impact(.medium)
            state.removeAsset(asset)
        case .left:
            HapticFeedback.impact(.heavy)
            // Add to queue (batch delete to reduce iOS confirmation dialogs)
            // Don't record as delete category until actually deleted
            // Create undo record (to show undo button)
            let previousCategory = sortStore.category(for: asset.id)
            // Create undo record (record that it was added to delete queue)
            sortStore.createUndoRecord(assetID: asset.id, previousCategory: previousCategory)
            // Just add to delete queue (don't record as delete category yet)
            state.deleteQueue.append(asset)
            state.removeAsset(asset)
        case .none:
            break
        }
        
        advanceAfterSortingAction()
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
                logger.warning("Failed to set favorite status: \(error.localizedDescription)")
            }
        }
        
        // Animate out after heart animation
        Task {
            try? await Task.sleep(for: .milliseconds(TimingConstants.sleepLong))
            
            // Hide heart animation before card animation starts
            await MainActor.run {
                state.showHeartAnimation = false
            }
            
            await preloadNextImage()
            
            state.isAnimatingOut = true
            
            withAnimation(.easeOut(duration: TimingConstants.durationMedium)) {
                state.imageOpacity = 0
            }
            
            try? await Task.sleep(for: .milliseconds(TimingConstants.sleepNormal))
            
            // Clear old image before moving to next
            state.currentImage = nil
            state.currentLivePhoto = nil
            
            state.removeAsset(asset)
            advanceAfterSortingAction()
            
            if let next = state.nextImage {
                state.currentImage = next
                state.nextImage = nil
            }
            
            state.isAnimatingOut = false
            
            withAnimation(.easeIn(duration: TimingConstants.durationNormal)) {
                state.imageOpacity = 1.0
            }
        }
    }
    
    private func performUndo() async {
        // Prevent rapid taps: skip if already undoing or animating
        guard !state.isUndoing, !state.isAnimatingOut else { return }
        
        // Start undo process
        state.isUndoing = true
        defer { state.isUndoing = false }  // Ensure flag is reset even on error
        
        // Reset heart animation when undoing
        state.showHeartAnimation = false
        
        if let assetID = sortStore.undo() {
            // Also cancel from delete queue (if in queue)
            if let index = state.deleteQueue.firstIndex(where: { $0.id == assetID }) {
                let asset = state.deleteQueue[index]
                state.deleteQueue.remove(at: index)
                
                // undo() already restored to previousCategory, just remove from delete queue here
                // Restore asset to unsorted list (if undo() restored category to unsorted)
                let currentCategory = sortStore.category(for: assetID)
                if currentCategory == nil {
                    state.restoreAssetToUnsorted(asset, atStart: true)
                }
            } else if let asset = photoLibrary.allAssets.first(where: { $0.id == assetID }) {
                // Normal undo process (if not in delete queue)
                // undo() already restored to previousCategory
                // If the undone action was a favorite, remove from iOS Favorites
                let currentCategory = sortStore.category(for: assetID)
                if currentCategory == .favorite {
                    do {
                        try await photoLibrary.setFavorite(asset.asset, isFavorite: false)
                    } catch {
                        // Non-critical: Favorite status update failed, but undo continues
                        logger.warning("Failed to remove favorite status: \(error.localizedDescription)")
                    }
                }
                
                // Add to unsorted list only if category was restored to unsorted
                if currentCategory == nil {
                    state.restoreAssetToUnsorted(asset, atStart: true)
                }
            }
            
            state.currentIndex = 0
            state.updateCurrentAsset()
            state.isComplete = false
            
            await loadCurrentImage()
            
            // Animate card left then back (only when actually undoing)
            withAnimation(.photoSlide) {
                state.offset = CGSize(width: CardAnimation.undoAnimationOffset, height: 0)
                state.imageOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(TimingConstants.sleepShort))
            withAnimation(.photoSlide) {
                state.offset = .zero
                state.imageOpacity = 1.0
            }
            HapticFeedback.impact(.light)
        }
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
        
        state.allAssets = allAssets  // Keep all assets (for category filter)
        state.allUnsortedAssets = allAssets.filter { !sortedIDs.contains($0.id) }
        state.totalCount = allAssets.count
        state.applyFilter(state.currentFilter, sortStore: sortStore)  // Apply current filter with category filter
        
        await loadCurrentImage()
        
        // Show swipe hint for first-time users
        if !hasSeenSwipeHint && !state.unsortedAssets.isEmpty {
            try? await Task.sleep(for: .milliseconds(TimingConstants.swipeHintDelay))
            withAnimation(.easeOut(duration: TimingConstants.durationSlow)) {
                showSwipeHint = true
            }
        }
    }
    
    /// Schedules an image load, cancelling any pending load task
    private func scheduleImageLoad() {
        imageLoadTask?.cancel()
        imageLoadTask = Task {
            await loadCurrentImage()
        }
    }
    
    private func loadCurrentImage() async {
        // Check for cancellation at the start
        guard !Task.isCancelled else { return }
        
        guard let asset = state.currentAsset else {
            // Clear old images when no asset
            state.currentImage = nil
            state.currentLivePhoto = nil
            state.currentBurstCount = nil
            return
        }
        
        // Save target asset ID (to prevent race conditions)
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
            width: min(screenSize.width * scale * 2, ImageConstants.maxImageSize),
            height: min(screenSize.height * scale * 2, ImageConstants.maxImageSize)
        )
        
        // Load main image (use fast preview for RAW images)
        let image = await photoLibrary.loadImage(
            for: asset.asset,
            targetSize: optimalSize,
            preferFastPreview: asset.isRAW
        )
        
        // Verify asset hasn't changed (prevent race conditions)
        guard !Task.isCancelled, state.currentAsset?.id == targetAssetID else {
            state.isLoadingImage = false
            return
        }
        
        state.currentImage = image
        state.isLoadingImage = false
        
        withAnimation(.easeIn(duration: TimingConstants.durationMedium)) {
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
        
        // Verify asset hasn't changed
        guard !Task.isCancelled, state.currentAsset?.id == targetAssetID else {
            state.isLoadingImage = false
            return
        }
        
        // Update state with results
        state.currentLivePhoto = livePhoto
        state.currentBurstCount = burstCount

        // Video item creates new instance on each playback,
        // so don't load here (loaded inside VideoPlayerView)
        
        photoLibrary.updateCacheWindow(currentIndex: state.currentIndex, assets: state.unsortedAssets)
        
        await preloadNextImage()
    }
    
    /// Batch delete queued assets (reduces iOS confirmation dialogs to one)
    private func flushDeleteQueue() async {
        guard !state.deleteQueue.isEmpty else { return }
        
        let assetsToDelete = state.deleteQueue
        // Note: Don't clear deleteQueue here - wait until deletion succeeds
        // This prevents UI count from temporarily decreasing during async deletion
        
        do {
            try await photoLibrary.deleteAssets(assetsToDelete.map { $0.asset })
            // On success: clear delete queue and record as delete category
            state.deleteQueue.removeAll()
            let deletedIDs = Set(assetsToDelete.map { $0.id })
            for asset in assetsToDelete {
                // Remove existing undo record (can't undo after actual deletion)
                sortStore.removeUndoRecord(for: asset.id)
                
                let previousCategory = sortStore.category(for: asset.id)
                // Record as delete category when actually deleted (don't create undo record)
                sortStore.addOrUpdate(assetID: asset.id, category: .delete, previousCategory: previousCategory, recordUndo: false)
            }
            // Remove deleted assets from all asset lists and update totalCount
            state.allAssets.removeAll { deletedIDs.contains($0.id) }
            state.allUnsortedAssets.removeAll { deletedIDs.contains($0.id) }
            state.unsortedAssets.removeAll { deletedIDs.contains($0.id) }
            state.totalCount = state.allAssets.count
            
            // Update current index and asset after deletion
            state.currentIndex = min(state.currentIndex, max(0, state.unsortedAssets.count - 1))
            state.updateCurrentAsset()
            
            // Complete if both unsorted assets and delete queue are empty after deletion
            if state.allUnsortedAssets.isEmpty && state.deleteQueue.isEmpty {
                state.isComplete = true
            } else {
                // Reload current image if not complete
                await loadCurrentImage()
            }
        } catch {
            // On failure: restore delete queue (keep undo records)
            state.deleteQueue = assetsToDelete
            for asset in assetsToDelete {
                // Remove delete record (since not actually deleted)
                sortStore.remove(assetID: asset.id)
                // Restore asset to unsorted list
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
        let startIndex = state.currentIndex + 1
        let endIndex = min(startIndex + CacheConstants.cacheAheadCount, state.unsortedAssets.count)
        
        guard startIndex < state.unsortedAssets.count else {
            state.nextImage = nil
            return
        }
        
        // Calculate optimal image size for preloading
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let optimalSize = CGSize(
            width: min(screenSize.width * scale * 2, ImageConstants.maxImageSize),
            height: min(screenSize.height * scale * 2, ImageConstants.maxImageSize)
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
        VStack(spacing: ThemeLayout.paddingLarge) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(ThemeLayout.opacityLight), lineWidth: ThemeLayout.lineWidthMedium)
                    .frame(width: ThemeLayout.iconContainerMedium, height: ThemeLayout.iconContainerMedium)
                
                Circle()
                    .trim(from: 0, to: photoLibrary.loadingProgress)
                    .stroke(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: ThemeLayout.lineWidthMedium, lineCap: .round)
                    )
                    .frame(width: ThemeLayout.iconContainerMedium, height: ThemeLayout.iconContainerMedium)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: photoLibrary.loadingProgress)
                
                Text("\(Int(photoLibrary.loadingProgress * 100))%")
                    .font(.themeCaption)
                    .foregroundStyle(Color.themeSecondary)
            }
            
            Text(NSLocalizedString("Loading Photos...", comment: "Loading photos message"))
                .font(.themeBodyMedium)
                .foregroundStyle(Color.themeSecondary)
        }
    }
    
    private var emptyView: some View {
        // Check if filter is active
        let isFilterActive = state.currentFilter != .all || state.selectedCategoryFilter != nil
        
        return VStack(spacing: ThemeLayout.spacingSection) {
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
                    .frame(width: ThemeLayout.iconContainerXLarge, height: ThemeLayout.iconContainerXLarge)
                
                Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle" : "photo.on.rectangle.angled")
                    .font(.themeDisplayXXLarge)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            VStack(spacing: ThemeLayout.spacingMediumLarge) {
                Text(isFilterActive ? NSLocalizedString("No Matching Photos", comment: "No matching photos message") : NSLocalizedString("No Photos", comment: "No photos message"))
                    .font(.themeTitle)
                    .foregroundStyle(Color.themePrimary)
                
                Text(isFilterActive ? NSLocalizedString("No Matching Photos Description", comment: "No matching photos description") : NSLocalizedString("No Photos Description", comment: "No photos description"))
                    .font(.themeBody)
                    .foregroundStyle(Color.themeSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(ThemeLayout.lineSpacingDefault)
            }
            
            if isFilterActive {
                // Clear filter button (main action when filter is active)
                Button {
                    withAnimation(.buttonPress) {
                        state.applyCategoryFilter(nil, sortStore: sortStore)
                        state.applyFilter(.all, sortStore: sortStore)
                    }
                    scheduleImageLoad()
                } label: {
                    Text(NSLocalizedString("Clear Filter", comment: "Clear filter button"))
                        .font(.themeButton)
                        .foregroundStyle(Color.themePrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ThemeLayout.spacingItem)
                        .background {
                            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                }
                .padding(.horizontal, ThemeLayout.spacingXLarge)
            } else {
                // Reload button (main action when no filter and no photos)
                Button {
                    Task {
                        await loadAssets()
                    }
                } label: {
                    Text(NSLocalizedString("Reload", comment: "Reload button"))
                        .font(.themeButton)
                        .foregroundStyle(Color.themePrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ThemeLayout.spacingItem)
                        .background {
                            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                }
                .padding(.horizontal, ThemeLayout.spacingXLarge)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var completedView: some View {
        VStack(spacing: ThemeLayout.spacingSection) {
            completedSuccessAnimation
            completedTitleSection
            completedStatsSection
            completedDeleteSection
        }
        .padding(ThemeLayout.paddingLarge)
    }
    
    private var completedSuccessAnimation: some View {
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
                .frame(width: ThemeLayout.iconContainerXLarge, height: ThemeLayout.iconContainerXLarge)
            
            Image(systemName: "checkmark.circle.fill")
                .font(.themeDisplayHuge)
                .foregroundStyle(Color.keepColor)
        }
    }
    
    private var completedTitleSection: some View {
        VStack(spacing: ThemeLayout.paddingSmall) {
            Text(NSLocalizedString("All Done!", comment: "All done title"))
                .font(.themeTitleLarge)
                .foregroundStyle(Color.themePrimary)
            
            Text(NSLocalizedString("All photos have been sorted.", comment: "All photos sorted message"))
                .font(.themeBody)
                .foregroundStyle(Color.themeTertiary)
        }
    }
    
    private var completedStatsSection: some View {
        HStack(spacing: ThemeLayout.spacingItem) {
            CompletedStat(
                count: sortStore.keepCount,
                label: NSLocalizedString("Kept", comment: "Kept label"),
                color: .keepColor,
                icon: "checkmark.circle.fill",
                onForcePress: {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        albumViewCategory = .keep
                        showAlbumView = true
                        HapticFeedback.impact(.medium)
                    }
                }
            )
            CompletedStat(
                count: sortStore.deleteCount,
                label: NSLocalizedString("Deleted", comment: "Deleted label"),
                color: .deleteColor,
                icon: "trash.circle.fill"
            )
            CompletedStat(
                count: sortStore.favoriteCount,
                label: NSLocalizedString("Favorites", comment: "Favorites label"),
                color: .favoriteColor,
                icon: "heart.circle.fill",
                onForcePress: {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        albumViewCategory = .favorite
                        showAlbumView = true
                        HapticFeedback.impact(.medium)
                    }
                }
            )
        }
        .padding(.top, ThemeLayout.paddingSmall)
    }
    
    private var completedDeleteSection: some View {
        Group {
            if !state.deleteQueue.isEmpty {
                VStack(spacing: ThemeLayout.spacingItem) {
                    HStack(spacing: 0) {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: ThemeLayout.spacingSmall) {
                                Image(systemName: "trash.fill")
                                    .font(.themeButton)
                                Text(String(format: NSLocalizedString("Delete %d Items", comment: "Delete items button"), state.deleteQueue.count))
                                    .font(.themeButton)
                                    .monospacedDigit()
                            }
                            .foregroundStyle(Color.deleteColor)
                            .padding(.horizontal, ThemeLayout.spacingItem)
                        }
                        
                        Rectangle()
                            .fill(Color.themeTertiary)
                            .frame(width: ThemeLayout.lineWidthThin, height: ThemeLayout.dividerHeightLarge)
                        
                        Button {
                            withAnimation(.buttonPress) {
                                clearDeleteQueue()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.themeButtonSmall)
                                .foregroundStyle(Color.themeSecondary)
                                .padding(.horizontal, ThemeLayout.spacingItem)
                        }
                    }
                    .frame(height: ThemeLayout.spacingXXLarge)
                    .background(Color.black.opacity(ThemeLayout.opacityHeavy))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusCard, style: .continuous))
                    .shadow(color: .black.opacity(ThemeLayout.shadowOpacitySmall), radius: ThemeLayout.shadowRadiusSmall, x: 0, y: ThemeLayout.shadowYSmall)
                    
                    Text(NSLocalizedString("Cancel with X", comment: "Cancel with X message"))
                        .font(.themeCaptionSecondary)
                        .foregroundStyle(Color.themeTertiary)
                }
                .padding(.top, ThemeLayout.spacingItem)
            }
        }
    }
}

// MARK: - Date Range Picker View

@available(iOS 18.0, *)
struct DateRangePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        NSLocalizedString("Start Date", comment: "Start date"),
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        NSLocalizedString("End Date", comment: "End date"),
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                } header: {
                    Text(NSLocalizedString("Date Range", comment: "Date range section"))
                }
            }
            .navigationTitle(NSLocalizedString("Filter by Date Range", comment: "Filter by date range title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Apply", comment: "Apply button")) {
                        dismiss()
                        onApply()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
