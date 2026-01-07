//
//  LivePhotoView.swift
//  SwipeSort
//
//  UIViewRepresentable wrapper for PHLivePhotoView
//

import SwiftUI
import PhotosUI

/// SwiftUI wrapper for PHLivePhotoView
struct LivePhotoPlayerView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    @Binding var isPlaying: Bool
    
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.contentMode = .scaleAspectFit
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
        
        if isPlaying {
            uiView.startPlayback(with: .full)
        } else {
            uiView.stopPlayback()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, PHLivePhotoViewDelegate {
        let parent: LivePhotoPlayerView
        
        init(parent: LivePhotoPlayerView) {
            self.parent = parent
        }
        
        func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            DispatchQueue.main.async {
                self.parent.isPlaying = false
            }
        }
    }
}

/// Container view for Live Photo with playback controls
struct LivePhotoContainer: View {
    let livePhoto: PHLivePhoto
    @Binding var isPlaying: Bool
    
    var body: some View {
        ZStack {
            LivePhotoPlayerView(livePhoto: livePhoto, isPlaying: $isPlaying)
            
            // Play indicator when not playing
            if !isPlaying {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "livephoto")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .padding(16)
                    }
                }
            }
        }
    }
}
