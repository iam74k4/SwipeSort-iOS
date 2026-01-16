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
    
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
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
    
    // MARK: - Initialization
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization Methods
    
    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    @MainActor
    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
    }
}
