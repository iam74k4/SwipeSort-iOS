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
                    Text("写真へのアクセスが必要です")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("SwipeSortは写真と動画を整理するために、\nフォトライブラリへのアクセスが必要です。")
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
                    Text("アクセスを許可")
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
        .alert("保存に関するお知らせ", isPresented: $showStorageAlert) {
            Button("OK") {}
        } message: {
            Text(storageAlertMessage)
        }
    }

    private func showStorageAlertIfNeeded() {
        guard !didShowStorageAlert else { return }
        didShowStorageAlert = true

        // Priority: critical > fallback > non-critical error
        if sortStore.isCriticalError {
            storageAlertMessage = "端末内への保存領域の初期化に失敗しました。\n\n整理結果は保存されず、アプリを終了すると失われる可能性があります。端末の空き容量を確保して再起動してください。"
            showStorageAlert = true
            return
        }

        if sortStore.isUsingFallbackStorage {
            storageAlertMessage = "端末内への保存領域の初期化に失敗したため、一時的な保存（メモリ上）で動作しています。\n\nアプリを終了すると整理結果が失われます。端末の空き容量を確保して再起動してください。"
            showStorageAlert = true
            return
        }

        if sortStore.hasStorageError {
            storageAlertMessage = "保存領域の初期化で問題が発生しました。\n\n一部の整理結果が保存されない可能性があります。端末の空き容量を確保して再起動してください。"
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
                    Text("アクセスが拒否されています")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("設定アプリからSwipeSortへの\n写真アクセスを許可してください。")
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
                    Text("設定を開く")
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
