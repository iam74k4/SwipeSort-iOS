//
//  RootView.swift
//  SwipeSort
//
//  Root view handling authorization and navigation
//

import SwiftUI
import UIKit
@preconcurrency import Photos

@available(iOS 18.0, *)
struct RootView: View {
    @State private var appState = AppState()
    @State private var photoLibrary = PhotoLibraryClient()
    @State private var sortStore = SortResultStore()

    @State private var didShowStorageAlert = false
    @State private var showStorageAlert = false
    @State private var storageAlertMessage = ""
    
    var body: some View {
        Group {
            switch appState.authorizationStatus {
            case .notDetermined:
                requestAccessView
            case .authorized, .limited:
                mainContentView
            case .denied, .restricted:
                deniedAccessView
            @unknown default:
                requestAccessView
            }
        }
        .onAppear {
            appState.checkAuthorizationStatus()
        }
    }
    
    // MARK: - Request Access View
    
    private var requestAccessView: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: ThemeLayout.spacingSection) {
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
                    
                    Image(systemName: "photo.stack")
                        .font(.themeDisplayHuge)
                        .foregroundStyle(.white.opacity(ThemeLayout.opacityXHeavy))
                }
                
                VStack(spacing: ThemeLayout.spacingMediumLarge) {
                    Text(NSLocalizedString("Photo Access Required", comment: "Photo access required"))
                        .font(.themeTitle)
                        .foregroundStyle(Color.themePrimary)
                    
                    Text(NSLocalizedString("Photo Access Description", comment: "Photo access description"))
                        .font(.themeBody)
                        .foregroundStyle(Color.themeSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(ThemeLayout.lineSpacingDefault)
                }
                
                Button {
                    Task {
                        await appState.requestAuthorization()
                    }
                } label: {
                    Text(NSLocalizedString("Allow Access", comment: "Allow access button"))
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
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        TabView(selection: $appState.selectedTab) {
            SortingFeature(photoLibrary: photoLibrary, sortStore: sortStore)
                .tabItem {
                    Label(AppState.Tab.sorting.title, systemImage: AppState.Tab.sorting.icon)
                }
                .tag(AppState.Tab.sorting)
            
            SettingsFeature(sortStore: sortStore)
                .tabItem {
                    Label(AppState.Tab.settings.title, systemImage: AppState.Tab.settings.icon)
                }
                .tag(AppState.Tab.settings)
        }
        .tint(Color.themePrimary)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.appBackground, for: .tabBar)
        .onAppear {
            showStorageAlertIfNeeded()
        }
        .alert(NSLocalizedString("Storage Alert Title", comment: "Storage alert title"), isPresented: $showStorageAlert) {
            Button(NSLocalizedString("OK", comment: "OK button")) {}
        } message: {
            Text(storageAlertMessage)
        }
    }

    private func showStorageAlertIfNeeded() {
        guard !didShowStorageAlert else { return }
        didShowStorageAlert = true

        // Priority: critical > fallback > non-critical error
        if sortStore.isCriticalError {
            storageAlertMessage = NSLocalizedString("Storage Critical Error", comment: "Storage critical error")
            showStorageAlert = true
            return
        }

        if sortStore.isUsingFallbackStorage {
            storageAlertMessage = NSLocalizedString("Storage Fallback Error", comment: "Storage fallback error")
            showStorageAlert = true
            return
        }

        if sortStore.hasStorageError {
            storageAlertMessage = NSLocalizedString("Storage Error", comment: "Storage error")
            showStorageAlert = true
        }
    }
    
    // MARK: - Denied Access View
    
    private var deniedAccessView: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: ThemeLayout.spacingSection) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.red.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: ThemeLayout.iconContainerXLarge, height: ThemeLayout.iconContainerXLarge)
                    
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.themeDisplayXXLarge)
                        .foregroundStyle(.red.opacity(ThemeLayout.opacityXHeavy))
                }
                
                VStack(spacing: ThemeLayout.spacingMediumLarge) {
                    Text(NSLocalizedString("Access Denied", comment: "Access denied"))
                        .font(.themeTitle)
                        .foregroundStyle(Color.themePrimary)
                    
                    Text(NSLocalizedString("Access Denied Description", comment: "Access denied description"))
                        .font(.themeBody)
                        .foregroundStyle(Color.themeSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(ThemeLayout.lineSpacingDefault)
                }
                
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(NSLocalizedString("Open Settings", comment: "Open settings button"))
                        .font(.themeButton)
                        .foregroundStyle(Color.themePrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ThemeLayout.spacingItem)
                        .glassCard(cornerRadius: ThemeLayout.cornerRadiusButton)
                }
                .padding(.horizontal, ThemeLayout.spacingXLarge)
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    if #available(iOS 18.0, *) {
        RootView()
    }
}
