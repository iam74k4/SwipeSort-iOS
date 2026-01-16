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
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Request Access View
    
    private var requestAccessView: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
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
                    
                    Image(systemName: "photo.stack")
                        .font(.system(size: 70, weight: .thin))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                VStack(spacing: 12) {
                    Text(NSLocalizedString("Photo Access Required", comment: "Photo access required"))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(NSLocalizedString("Photo Access Description", comment: "Photo access description"))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                Button {
                    Task {
                        await appState.requestAuthorization()
                    }
                } label: {
                    Text(NSLocalizedString("Allow Access", comment: "Allow access button"))
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
        .tint(.white)
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
            
            VStack(spacing: 32) {
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
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(.red.opacity(0.8))
                }
                
                VStack(spacing: 12) {
                    Text(NSLocalizedString("Access Denied", comment: "Access denied"))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(NSLocalizedString("Access Denied Description", comment: "Access denied description"))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(NSLocalizedString("Open Settings", comment: "Open settings button"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .glassCard(cornerRadius: 14)
                }
                .padding(.horizontal, 40)
                
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
