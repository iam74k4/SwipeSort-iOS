//
//  AlbumView.swift
//  SwipeSort
//
//  Album view for adding photos to albums via drag and drop
//

import SwiftUI
@preconcurrency import Photos
import UniformTypeIdentifiers

/// Transferable struct for drag and drop
struct AssetTransferable: Transferable, Codable {
    let assetID: String
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

@available(iOS 18.0, *)
struct AlbumView: View {
    let category: SortCategory
    @Bindable var photoLibrary: PhotoLibraryClient
    @Bindable var sortStore: SortResultStore
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var albums: [PHAssetCollection] = []
    @State private var isLoadingAlbums = false
    @State private var photos: [PhotoAsset] = []
    @State private var addedPhotoIDs: Set<String> = []
    @State private var showAlbumError = false
    @State private var albumErrorMessage = ""
    @State private var showCreateAlbumAlert = false
    @State private var newAlbumName = ""
    @State private var isCreatingAlbum = false
    @State private var selectedAlbumID: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if isLoadingAlbums {
                    ProgressView()
                        .tint(.white)
                } else if photos.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        // Album selection area
                        albumSelectionArea
                        
                        Divider()
                            .background(Color.appBackgroundSecondary)
                        
                        // Photo grid
                        photoGrid
                    }
                }
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Close", comment: "Close button")) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadData()
            }
            .alert(NSLocalizedString("Album Error", comment: "Album error title"), isPresented: $showAlbumError) {
                Button(NSLocalizedString("OK", comment: "OK button")) {}
            } message: {
                Text(albumErrorMessage)
            }
            .alert(NSLocalizedString("Create Album", comment: "Create album title"), isPresented: $showCreateAlbumAlert) {
                TextField(NSLocalizedString("Album Name", comment: "Album name placeholder"), text: $newAlbumName)
                Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                    newAlbumName = ""
                }
                Button(NSLocalizedString("Create", comment: "Create button")) {
                    Task {
                        await createAlbum()
                    }
                }
                .disabled(newAlbumName.trimmingCharacters(in: .whitespaces).isEmpty || isCreatingAlbum)
            } message: {
                Text(NSLocalizedString("Enter album name", comment: "Enter album name message"))
            }
        }
    }
    
    // MARK: - Album Selection Area
    
    private var albumSelectionArea: some View {
        VStack(alignment: .leading, spacing: ThemeLayout.spacingMediumLarge) {
            Text(NSLocalizedString("Select Album", comment: "Select album label"))
                .font(.themeBodyMedium)
                .foregroundStyle(Color.themePrimary)
                .padding(.horizontal, ThemeLayout.paddingLarge - 8)
                .padding(.top, ThemeLayout.paddingLarge - 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ThemeLayout.spacingItem) {
                    // Create new album button
                    createAlbumButton
                    
                    // Existing albums
                    ForEach(albums, id: \.localIdentifier) { album in
                        AlbumItem(
                            album: album,
                            isSelected: selectedAlbumID == album.localIdentifier,
                            onSelect: {
                                selectedAlbumID = album.localIdentifier
                            },
                            photoLibrary: photoLibrary
                        )
                        .dropDestination(for: AssetTransferable.self) { items, _ in
                            handleDrop(items: items, to: album)
                        }
                    }
                }
                .padding(.horizontal, ThemeLayout.paddingLarge - 8)
            }
            .padding(.bottom, ThemeLayout.paddingLarge - 8)
        }
        .background(.themeBarMaterial)
    }
    
    private var createAlbumButton: some View {
        Button {
            showCreateAlbumAlert = true
        } label: {
            VStack(spacing: ThemeLayout.paddingSmall) {
                Image(systemName: "plus.circle.fill")
                    .font(.themeIconLarge)
                    .foregroundStyle(Color.themeSecondary)
                Text(NSLocalizedString("New Album", comment: "New album label"))
                    .font(.themeCaptionSecondary)
                    .foregroundStyle(Color.themeSecondary)
            }
            .frame(width: 100, height: 100)
            .background(Color.appBackgroundSecondary)
            .cornerRadius(ThemeLayout.cornerRadiusChip)
        }
        .disabled(isCreatingAlbum)
    }
    
    // MARK: - Photo Grid
    
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: ThemeLayout.paddingSmall),
                GridItem(.flexible(), spacing: ThemeLayout.paddingSmall),
                GridItem(.flexible(), spacing: ThemeLayout.paddingSmall)
            ], spacing: ThemeLayout.paddingSmall) {
                ForEach(photos) { photo in
                    PhotoThumbnail(
                        photo: photo,
                        isAdded: addedPhotoIDs.contains(photo.id),
                        photoLibrary: photoLibrary
                    )
                    .draggable(AssetTransferable(assetID: photo.id))
                }
            }
            .padding(ThemeLayout.paddingLarge - 8)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: ThemeLayout.spacingItem) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.themeDisplayXXLarge)
                .foregroundStyle(Color.themeTertiary)
            
            Text(NSLocalizedString("No photos in this category", comment: "No photos message"))
                .font(.themeTitle)
                .foregroundStyle(Color.themePrimary)
        }
    }
    
    // MARK: - Methods
    
    private func loadData() async {
        // Load photos
        let photoIDs: [String]
        switch category {
        case .keep:
            photoIDs = sortStore.keepIDs
        case .favorite:
            photoIDs = sortStore.favoriteIDs
        default:
            photoIDs = []
        }
        photos = photoLibrary.assets(for: photoIDs)
        
        // Load albums
        isLoadingAlbums = true
        do {
            albums = try await photoLibrary.fetchUserAlbums()
        } catch {
            albumErrorMessage = error.localizedDescription
            showAlbumError = true
        }
        isLoadingAlbums = false
    }
    
    private func createAlbum() async {
        let trimmedName = newAlbumName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        isCreatingAlbum = true
        do {
            let newAlbum = try await photoLibrary.createAlbum(name: trimmedName)
            if let album = newAlbum {
                albums.append(album)
                selectedAlbumID = album.localIdentifier
                newAlbumName = ""
            }
        } catch {
            albumErrorMessage = error.localizedDescription
            showAlbumError = true
        }
        isCreatingAlbum = false
    }
    
    private func handleDrop(items: [AssetTransferable], to album: PHAssetCollection) -> Bool {
        guard !items.isEmpty else { return false }
        
        Task {
            let assetIDs = items.map { $0.assetID }
            let assets = photos.filter { assetIDs.contains($0.id) }.map { $0.asset }
            
            do {
                let addedCount = try await photoLibrary.addAssets(assets, to: album)
                if addedCount > 0 {
                    // Mark photos as added
                    for id in assetIDs {
                        addedPhotoIDs.insert(id)
                    }
                    HapticFeedback.notification(.success)
                }
            } catch {
                await MainActor.run {
                    albumErrorMessage = error.localizedDescription
                    showAlbumError = true
                }
            }
        }
        
        return true
    }
}

// MARK: - Supporting Views

@available(iOS 18.0, *)
struct AlbumItem: View {
    let album: PHAssetCollection
    let isSelected: Bool
    let onSelect: () -> Void
    let photoLibrary: PhotoLibraryClient
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: ThemeLayout.paddingSmall) {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(ThemeLayout.cornerRadiusChip)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.appBackgroundSecondary)
                        .frame(width: 80, height: 80)
                        .cornerRadius(ThemeLayout.cornerRadiusChip)
                        .overlay {
                            Image(systemName: "photo.stack")
                                .font(.themeTitle)
                                .foregroundStyle(Color.themeTertiary)
                        }
                }
                
                Text(album.localizedTitle ?? "")
                    .font(.themeCaptionSecondary)
                    .foregroundStyle(Color.themePrimary)
                    .lineLimit(1)
            }
            .frame(width: 100)
            .padding(ThemeLayout.paddingSmall)
            .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
            .cornerRadius(ThemeLayout.cornerRadiusChip)
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
        
        if let firstAsset = assets.firstObject {
            thumbnail = await photoLibrary.loadImage(for: firstAsset, targetSize: CGSize(width: 160, height: 160))
        }
    }
}

@available(iOS 18.0, *)
struct PhotoThumbnail: View {
    let photo: PhotoAsset
    let isAdded: Bool
    let photoLibrary: PhotoLibraryClient
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.appBackgroundSecondary)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .frame(width: 100, height: 100)
        .cornerRadius(ThemeLayout.cornerRadiusChip)
        .clipped()
        .overlay {
            if isAdded {
                Color.black.opacity(ThemeLayout.opacityHeavy)
                    .overlay {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.themeTitle)
                            .foregroundStyle(.white)
                    }
            }
        }
        .opacity(isAdded ? 0.6 : 1.0)
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        thumbnail = await photoLibrary.loadImage(for: photo.asset, targetSize: CGSize(width: 200, height: 200))
    }
}
