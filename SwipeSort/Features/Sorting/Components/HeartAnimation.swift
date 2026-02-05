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
    @State private var animationTrigger: Int = 0
    
    var body: some View {
        ZStack {
            Image(systemName: "heart.fill")
                .font(.themeIconHuge)
                .foregroundStyle(.pink)
                .symbolEffect(.bounce, value: animationTrigger)
                .scaleEffect(isAnimating ? 1.0 : 0.0)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
        }
        .allowsHitTesting(false)
        .onChange(of: isAnimating) { oldValue, newValue in
            // Auto-hide after animation when it becomes true
            if newValue {
                // Trigger bounce animation
                animationTrigger += 1
                
                // Auto-hide after animation
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    await MainActor.run {
                        isAnimating = false
                    }
                }
            }
        }
    }
}
