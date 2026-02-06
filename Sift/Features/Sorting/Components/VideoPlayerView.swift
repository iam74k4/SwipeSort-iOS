//
//  VideoPlayerView.swift
//  Sift
//
//  AVPlayerLayer wrapper for inline video playback
//

import SwiftUI
import AVFoundation
@preconcurrency import Photos

extension Notification.Name {
    static let videoSeekRequested = Notification.Name("videoSeekRequested")
}

/// Constants for video playback
private enum VideoConstants {
    static let preferredTimescale: CMTimeScale = 600
    static let timeUpdateInterval: Double = 0.1
}

struct VideoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    @Binding var isPlaying: Bool
    @Binding var isPaused: Bool
    @Binding var isSeeking: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.onTimeUpdate = { time, totalDuration in
            DispatchQueue.main.async {
                // Skip time updates while seeking (user drag takes priority)
                if !isSeeking {
                    currentTime = time
                }
                duration = totalDuration
            }
        }
        view.loadAsset(asset, shouldPlay: isPlaying && !isPaused)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        let assetID = asset.localIdentifier
        
        // Create new player item for different asset
        if uiView.currentAssetID != assetID {
            uiView.onTimeUpdate = { time, totalDuration in
                DispatchQueue.main.async {
                    if !isSeeking {
                        currentTime = time
                    }
                    duration = totalDuration
                }
            }
            uiView.loadAsset(asset, shouldPlay: isPlaying && !isPaused)
        } else {
            // Same asset - update playback state only
            if isPlaying {
                if isPaused || isSeeking {
                    // Paused or seeking
                    uiView.player?.pause()
                } else {
                    // Playing
                    if uiView.player != nil {
                        uiView.player?.play()
                    } else {
                        uiView.shouldPlayWhenReady = true
                    }
                }
            } else {
                uiView.player?.pause()
                uiView.player?.seek(to: .zero)
                uiView.shouldPlayWhenReady = false
            }
        }
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        guard let playerLayer = layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer, but got \(type(of: layer))")
        }
        return playerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            // Remove old observer
            removeTimeObserver()
            playerLayer.player = newValue
            playerForCleanup = newValue
            // Add observer to new player
            if newValue != nil {
                addTimeObserver()
            }
        }
    }
    
    var currentAssetID: String?
    var shouldPlayWhenReady: Bool = false
    var onTimeUpdate: ((Double, Double) -> Void)?
    
    /// Reference for cleanup in deinit (nonisolated access)
    nonisolated(unsafe) private var playerForCleanup: AVPlayer?
    
    private let imageManager = PHCachingImageManager()
    private var loadingTask: Task<Void, Never>?
    /// Note: nonisolated(unsafe) to allow access in deinit
    nonisolated(unsafe) private var timeObserverToken: Any?
    nonisolated(unsafe) private var seekObserver: NSObjectProtocol?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSeekObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSeekObserver()
    }
    
    private func setupSeekObserver() {
        seekObserver = NotificationCenter.default.addObserver(
            forName: .videoSeekRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let time = notification.userInfo?["time"] as? Double {
                Task { @MainActor in
                    self?.seek(to: time)
                }
            }
        }
    }

    func loadAsset(_ asset: PHAsset, shouldPlay: Bool) {
        let assetID = asset.localIdentifier
        
        // Cancel existing loading task
        loadingTask?.cancel()
        
        // Cleanup existing player
        if let existingPlayer = player {
            existingPlayer.pause()
            existingPlayer.replaceCurrentItem(with: nil)
        }
        
        // Update asset ID at load start for completion check
        let previousAssetID = currentAssetID
        currentAssetID = assetID
        shouldPlayWhenReady = shouldPlay
        
        // Create new AVPlayerItem (must create fresh instance each time)
        // AVPlayerItem cannot be reused once associated with an AVPlayer
        loadingTask = Task { @MainActor in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                imageManager.requestPlayerItem(forVideo: asset, options: options) { [weak self] item, _ in
                    guard let self = self, !Task.isCancelled else {
                        continuation.resume()
                        return
                    }
                    
                    // Verify asset hasn't changed during load
                    guard self.currentAssetID == assetID else {
                        continuation.resume()
                        return
                    }
                    
                    // Create new player
                    if let item = item {
                        let newPlayer = AVPlayer(playerItem: item)
                        self.player = newPlayer
                        
                        // Start playback if needed
                        if self.shouldPlayWhenReady {
                            newPlayer.play()
                        }
                    } else {
                        // Revert asset ID on load failure
                        if self.currentAssetID == assetID {
                            self.currentAssetID = previousAssetID
                        }
                        self.shouldPlayWhenReady = false
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: VideoConstants.preferredTimescale)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func addTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: VideoConstants.timeUpdateInterval, preferredTimescale: VideoConstants.preferredTimescale)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self,
                      let currentItem = self.player?.currentItem,
                      currentItem.status == .readyToPlay else { return }
                
                let currentTime = time.seconds
                let duration = currentItem.duration.seconds
                
                // Only call callback for valid values
                if currentTime.isFinite && duration.isFinite && duration > 0 {
                    self.onTimeUpdate?(currentTime, duration)
                }
            }
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    deinit {
        // Cancel loading task (thread-safe)
        loadingTask?.cancel()
        
        // Remove seek observer (thread-safe)
        if let observer = seekObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Capture references for cleanup on main thread
        // deinit can be called from any thread, so we dispatch to main
        let token = timeObserverToken
        let player = playerForCleanup
        
        if token != nil || player != nil {
            DispatchQueue.main.async {
                // Remove time observer
                if let token = token {
                    player?.removeTimeObserver(token)
                }
                
                // Cleanup player
                player?.pause()
                player?.replaceCurrentItem(with: nil)
            }
        }
    }
}

