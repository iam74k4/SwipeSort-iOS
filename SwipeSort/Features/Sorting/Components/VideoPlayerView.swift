//
//  VideoPlayerView.swift
//  SwipeSort
//
//  AVPlayerLayer wrapper for inline video playback
//

import SwiftUI
import AVFoundation

struct VideoPlayerView: UIViewRepresentable {
    let playerItem: AVPlayerItem
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.setPlayerItem(playerItem)

        if isPlaying {
            uiView.player?.play()
        } else {
            uiView.player?.pause()
            uiView.player?.seek(to: .zero)
        }
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    func setPlayerItem(_ item: AVPlayerItem) {
        if player == nil {
            player = AVPlayer(playerItem: item)
            return
        }

        if player?.currentItem !== item {
            player?.replaceCurrentItem(with: item)
        }
    }
}

