//
//  VideoPlayerView.swift
//  SwipeSort
//
//  AVPlayerLayer wrapper for inline video playback
//

import SwiftUI
import AVFoundation
@preconcurrency import Photos

struct VideoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    @Binding var isPlaying: Bool
    
    // assetIDを追跡して、同じアセットの場合は再作成を防ぐ
    private var assetID: String {
        asset.localIdentifier
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.loadAsset(asset, shouldPlay: isPlaying)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        let assetID = asset.localIdentifier
        
        // 異なるアセットの場合は、新しいプレイヤーアイテムを作成
        if uiView.currentAssetID != assetID {
            uiView.loadAsset(asset, shouldPlay: isPlaying)
        } else {
            // 同じアセットの場合は、再生状態のみ更新
            if isPlaying {
                // プレイヤーが準備できている場合は再生
                if uiView.player != nil {
                    uiView.player?.play()
                } else {
                    // プレイヤーがまだ読み込み中の場合は、読み込み完了後に再生するように設定
                    uiView.shouldPlayWhenReady = true
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
        set { playerLayer.player = newValue }
    }
    
    var currentAssetID: String?
    var shouldPlayWhenReady: Bool = false
    private let imageManager = PHCachingImageManager()
    private var loadingTask: Task<Void, Never>?

    func loadAsset(_ asset: PHAsset, shouldPlay: Bool) {
        let assetID = asset.localIdentifier
        
        // 既存の読み込みタスクをキャンセル
        loadingTask?.cancel()
        
        // 既存のプレイヤーをクリーンアップ
        if let existingPlayer = player {
            existingPlayer.pause()
            existingPlayer.replaceCurrentItem(with: nil)
        }
        
        // アセットIDを更新（新しいアセットまたは2回目の再生）
        // 読み込み完了後に更新するのではなく、読み込み開始時に更新して
        // 読み込み完了時のチェックで使用する
        let previousAssetID = currentAssetID
        currentAssetID = assetID
        shouldPlayWhenReady = shouldPlay
        
        // 新しいAVPlayerItemを作成（毎回新しいインスタンスを作成）
        // AVPlayerItemは一度AVPlayerに関連付けられると別のAVPlayerに再利用できないため、
        // 2回目の再生時にも新しいAVPlayerItemを作成する必要がある
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
                    
                    // アセットが変更されていないことを確認（読み込み中に変更された場合を検出）
                    guard self.currentAssetID == assetID else {
                        continuation.resume()
                        return
                    }
                    
                    // 新しいプレイヤーを作成
                    if let item = item {
                        let newPlayer = AVPlayer(playerItem: item)
                        self.player = newPlayer
                        
                        // 読み込み完了時に再生が必要な場合は再生を開始
                        if self.shouldPlayWhenReady {
                            newPlayer.play()
                        }
                    } else {
                        // 読み込み失敗時は、アセットIDを元に戻す（読み込み前の状態に戻す）
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
    
    deinit {
        // 読み込みタスクをキャンセル
        loadingTask?.cancel()
        
        // クリーンアップ（deinitは非同期コンテキストで呼ばれる可能性があるため、Taskを使用）
        // playerはMainActor上にあるため、MainActor.assumeIsolatedでアクセスしてからコピー
        let playerToCleanup = MainActor.assumeIsolated { player }
        Task { @MainActor in
            playerToCleanup?.pause()
            playerToCleanup?.replaceCurrentItem(with: nil)
        }
    }
}

