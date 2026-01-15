//
//  BurstSelectorView.swift
//  SwipeSort
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
                        .padding(.top, geometry.safeAreaInsets.top + 16)
                    
                    // Main preview
                    mainPreview
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    // Thumbnail strip
                    thumbnailStrip
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    // Action buttons
                    actionButtons
                        .padding(.horizontal, 20)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 24)
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
        VStack(spacing: 8) {
            Text("バースト写真")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            
            Text("\(burstAssets.count)枚から1枚を選択")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    // MARK: - Main Preview
    
    private var mainPreview: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                
                if isLoadingMain {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let image = mainImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // Selection indicator
                VStack {
                    HStack {
                        Text("\(selectedIndex + 1) / \(burstAssets.count)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(Color.black.opacity(0.6))
                            }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
    }
    
    // MARK: - Thumbnail Strip
    
    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(burstAssets.enumerated()), id: \.element.id) { index, asset in
                        thumbnailItem(index: index, asset: asset)
                            .id(index)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .frame(height: 80)
    }
    
    private func thumbnailItem(index: Int, asset: PhotoAsset) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedIndex = index
            }
        } label: {
            ZStack {
                if let thumbnail = thumbnails[asset.id] {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                }
                
                // Selection border
                if index == selectedIndex {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.cyan, lineWidth: 3)
                        .frame(width: 60, height: 60)
                    
                    // Checkmark
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white, .cyan)
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
        VStack(spacing: 12) {
            // Primary action - select this photo
            Button {
                let selected = burstAssets[selectedIndex]
                let others = burstAssets.enumerated()
                    .filter { $0.offset != selectedIndex }
                    .map { $0.element }
                onSelect(selected, others)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("これを残す（他を削除候補に）")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            HStack(spacing: 12) {
                Button {
                    onKeepAll()
                } label: {
                    Text("すべてKeep")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        }
                }
                
                Button {
                    onCancel()
                } label: {
                    Text("スキップ")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
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
