//
//  HeartAnimation.swift
//  SwipeSort
//
//  Heart animation for double tap favorite action
//

import SwiftUI

struct HeartAnimationView: View {
    @Binding var isAnimating: Bool
    
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var particles: [HeartParticle] = []
    
    var body: some View {
        ZStack {
            // Particles
            ForEach(particles) { particle in
                Image(systemName: "heart.fill")
                    .font(.system(size: particle.size))
                    .foregroundStyle(Color.favoriteColor)
                    .offset(particle.offset)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
            
            // Main heart
            Image(systemName: "heart.fill")
                .font(.system(size: 100, weight: .regular))
                .foregroundStyle(Color.favoriteColor)
                .scaleEffect(scale)
                .opacity(opacity)
                .shadow(color: .favoriteColor.opacity(0.5), radius: 20, x: 0, y: 0)
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                performAnimation()
            }
        }
    }
    
    private func performAnimation() {
        // Reset state
        scale = 0
        opacity = 1
        particles = generateParticles()
        
        // Main heart animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            scale = 1.2
        }
        
        // Bounce back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }
        
        // Animate particles
        for i in particles.indices {
            withAnimation(.easeOut(duration: 0.6).delay(Double(i) * 0.02)) {
                particles[i].offset = particles[i].targetOffset
                particles[i].opacity = 0
                particles[i].scale = 0.5
            }
        }
        
        // Fade out main heart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
                scale = 1.3
            }
        }
        
        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isAnimating = false
            particles = []
        }
    }
    
    private func generateParticles() -> [HeartParticle] {
        (0..<8).map { i in
            let angle = Double(i) * (360.0 / 8.0) * .pi / 180.0
            let distance: CGFloat = 80
            return HeartParticle(
                id: i,
                size: CGFloat.random(in: 16...28),
                offset: .zero,
                targetOffset: CGSize(
                    width: cos(angle) * distance,
                    height: sin(angle) * distance
                ),
                opacity: 1,
                scale: 1
            )
        }
    }
}

struct HeartParticle: Identifiable {
    let id: Int
    let size: CGFloat
    var offset: CGSize
    let targetOffset: CGSize
    var opacity: Double
    var scale: CGFloat
}

#Preview {
    ZStack {
        Color.black
        HeartAnimationView(isAnimating: .constant(true))
    }
}
