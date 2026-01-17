//
//  HeartAnimation.swift
//  SwipeSort
//
//  Heart animation view for favorite action
//

import SwiftUI

@available(iOS 18.0, *)
struct HeartAnimationView: View {
    @Binding var isAnimating: Bool
    
    var body: some View {
        ZStack {
            if isAnimating {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.pink)
                    .symbolEffect(.bounce, value: isAnimating)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                    .onAppear {
                        // Auto-hide after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isAnimating = false
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}
