//
//  BurstSelectorView.swift
//  Sift
//
//  UI for selecting the best photo from a burst sequence
//

import SwiftUI
@preconcurrency import Photos

@available(iOS 18.0, *)
struct BurstSelectorView: View {
    let burstAssets: [PhotoAsset]
    let photoLibrary: PhotoLibraryClient
    let onSelect: (PhotoAsset, [PhotoAsset]) -> Void  // (selected, others)
    let onCancel: () -> Void
    let onKeepAll: () -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var mainImage: UIImage?
    @State private var isLoadingMain = true
    
    private let thumbnailSize = CGSize(width: 100, height: 100)
    private let mainImageSize = CGSize(width: 800, height: 800)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, geometry.safeAreaInsets.top + ThemeLayout.spacingItem)
                    
                    // Main preview
                    mainPreview
                        .padding(.horizontal, ThemeLayout.spacingLarge)
                        .padding(.top, ThemeLayout.spacingItem)
                    
                    // Thumbnail strip
                    thumbnailStrip
                        .padding(.top, ThemeLayout.spacingLarge)
                    
                    Spacer()
                    
                    // Action buttons
                    actionButtons
                        .padding(.horizontal, ThemeLayout.spacingLarge)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + ThemeLayout.paddingLarge)
                }
            }
            .ignoresSafeArea()
        }
        .task {
            await loadThumbnails()
            await loadMainImage()
        }
        .onChange(of: selectedIndex) { _, _ in
            Task { await loadMainImage() }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: ThemeLayout.paddingSmall) {
            Text(NSLocalizedString("Burst Photos", comment: "Burst photos"))
                .font(.themeTitle.weight(.bold))
                .foregroundStyle(Color.themePrimary)
            
            Text(String(format: NSLocalizedString("Select 1 from %d Photos", comment: "Select 1 from N photos"), burstAssets.count))
                .font(.themeBody)
                .foregroundStyle(Color.themeSecondary)
        }
    }
    
    // MARK: - Main Preview
    
    private var mainPreview: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                    .fill(Color.primary.opacity(ThemeLayout.opacityXLight))
                
                if isLoadingMain {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.themePrimary))
                } else if let image = mainImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous))
                }
                
                // Selection indicator
                VStack {
                    HStack {
                        Text("\(selectedIndex + 1) / \(burstAssets.count)")
                            .font(.themeCaption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.themePrimary)
                            .padding(.horizontal, ThemeLayout.spacingItem)
                            .padding(.vertical, ThemeLayout.spacingSmall)
                            .background {
                                Capsule().fill(Color.cardBackground)
                            }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(ThemeLayout.spacingItem)
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
    }
    
    // MARK: - Thumbnail Strip
    
    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ThemeLayout.paddingSmall) {
                    ForEach(Array(burstAssets.enumerated()), id: \.element.id) { index, asset in
                        thumbnailItem(index: index, asset: asset)
                            .id(index)
                    }
                }
                .padding(.horizontal, ThemeLayout.spacingLarge)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: TimingConstants.durationNormal)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .frame(height: 80)
    }
    
    private func thumbnailItem(index: Int, asset: PhotoAsset) -> some View {
        Button {
            withAnimation(.easeInOut(duration: TimingConstants.durationFast)) {
                selectedIndex = index
            }
        } label: {
            ZStack {
                if let thumbnail = thumbnails[asset.id] {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                        .fill(Color.appBackgroundSecondary)
                        .frame(width: 60, height: 60)
                }
                
                // Selection border
                if index == selectedIndex {
                    RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                        .stroke(Color.iconMedia, lineWidth: 3)
                        .frame(width: 60, height: 60)
                    
                    // Checkmark
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.themeRowTitle)
                                .foregroundStyle(Color.themePrimary, Color.iconMedia)
                                .offset(x: 4, y: -4)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: ThemeLayout.spacingMediumLarge) {
            // Primary action - select this photo
            Button {
                let selected = burstAssets[selectedIndex]
                let others = burstAssets.enumerated()
                    .filter { $0.offset != selectedIndex }
                    .map { $0.element }
                onSelect(selected, others)
            } label: {
                HStack(spacing: ThemeLayout.paddingSmall) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.themeRowTitle.weight(.semibold))
                    Text(NSLocalizedString("Keep This (Delete Others)", comment: "Keep this and delete others"))
                        .font(.themeRowTitle.weight(.semibold))
                }
                .foregroundStyle(Color.themePrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ThemeLayout.spacingItem)
                .background {
                    RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            
            // Secondary actions
            HStack(spacing: ThemeLayout.spacingMediumLarge) {
                Button {
                    onKeepAll()
                } label: {
                    Text(NSLocalizedString("Keep All", comment: "Keep all"))
                        .font(.themeButtonSmall)
                        .foregroundStyle(Color.themePrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ThemeLayout.spacingItem - 2)
                        .background {
                            RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusChip, style: .continuous)
                                .fill(Color.appBackgroundSecondary)
                        }
                }
            }
        }
    }
    
    // MARK: - Loading
    
    private func loadThumbnails() async {
        for asset in burstAssets {
            if let thumbnail = await photoLibrary.loadThumbnail(for: asset.asset) {
                thumbnails[asset.id] = thumbnail
            }
        }
    }
    
    private func loadMainImage() async {
        guard selectedIndex < burstAssets.count else { return }
        
        isLoadingMain = true
        let asset = burstAssets[selectedIndex]
        mainImage = await photoLibrary.loadImage(for: asset.asset, targetSize: mainImageSize)
        isLoadingMain = false
    }
}
