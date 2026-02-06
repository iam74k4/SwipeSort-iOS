//
//  AppState.swift
//  SwipeSort
//
//  Global app state using @Observable
//

import SwiftUI
@preconcurrency import Photos

@MainActor
@Observable
final class AppState {
    // MARK: - Authorization
    
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }
    
    // MARK: - Navigation
    
    var selectedTab: Tab = .sorting
    
    enum Tab: Int, CaseIterable {
        case sorting = 0
        case settings = 1
        
        var title: String {
            switch self {
            case .sorting: return NSLocalizedString("Sort", comment: "Sort tab")
            case .settings: return NSLocalizedString("Settings", comment: "Settings tab")
            }
        }
        
        var icon: String {
            switch self {
            case .sorting: return "hand.draw"
            case .settings: return "gearshape"
            }
        }
    }
    
    // MARK: - Private
    
    /// Observer for notification changes
    private var notificationObserver: (any NSObjectProtocol)?
    
    // MARK: - Initialization
    
    init() {
        checkAuthorizationStatus()
        observeAuthorizationChanges()
    }
    
    /// Remove observer when no longer needed
    func cleanup() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }
    
    // MARK: - Authorization Methods
    
    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
    }
    
    // MARK: - Private Methods
    
    /// Observe app becoming active to detect authorization changes made in Settings app
    private func observeAuthorizationChanges() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAuthorizationStatus()
            }
        }
    }
}
