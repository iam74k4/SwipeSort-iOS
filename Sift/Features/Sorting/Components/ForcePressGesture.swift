//
//  ForcePressGesture.swift
//  Sift
//
//  Force Press gesture detection for album creation
//

import SwiftUI
import UIKit

/// A view that detects Force Press (3D Touch) gestures
struct ForcePressDetector: UIViewRepresentable {
    let onForcePress: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = ForcePressView()
        view.onForcePress = onForcePress
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

private class ForcePressView: UIView {
    var onForcePress: (() -> Void)?
    private var hasTriggered = false
    private var currentTouch: UITouch?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        hasTriggered = false
        currentTouch = touches.first
        // Also check on touch began in case force is already applied
        if let touch = touches.first {
            checkForcePress(touch: touch)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard !hasTriggered, let touch = touches.first else { return }
        currentTouch = touch
        checkForcePress(touch: touch)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        hasTriggered = false
        currentTouch = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        hasTriggered = false
        currentTouch = nil
    }
    
    private func checkForcePress(touch: UITouch) {
        // Check if device supports Force Touch
        guard traitCollection.forceTouchCapability == .available else {
            return
        }
        
        // Force Touch threshold (normalized: 0.0 to 1.0)
        // Using 0.4 (40% of maximum force) for easier detection
        let forceThreshold: CGFloat = 0.4
        
        // Normalize force (0.0 to 1.0)
        guard touch.maximumPossibleForce > 0 else { return }
        let normalizedForce = touch.force / touch.maximumPossibleForce
        
        // Check if normalized force exceeds threshold
        if normalizedForce >= forceThreshold {
            // Trigger only once per touch sequence
            if !hasTriggered {
                hasTriggered = true
                // Provide haptic feedback on main thread
                DispatchQueue.main.async {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                }
                // Call the callback on main thread
                DispatchQueue.main.async {
                    self.onForcePress?()
                }
            }
        }
    }
}

/// A view modifier that adds Force Press detection with long press fallback
struct ForcePressModifier: ViewModifier {
    let onForcePress: () -> Void
    
    @State private var supportsForceTouch: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                ForcePressDetector(onForcePress: {
                    // Force Touch detected - trigger immediately
                    onForcePress()
                })
            )
            .background(
                // Check Force Touch capability
                ForceTouchCapabilityChecker { supports in
                    supportsForceTouch = supports
                }
            )
            .onLongPressGesture(minimumDuration: 0.3) {
                // Long press fallback for non-Force Touch devices and simulator
                // Simulator doesn't support Force Touch, so always use long press
                // On real devices, only use if Force Touch is not available
                if !supportsForceTouch {
                    onForcePress()
                }
            }
    }
}

/// Helper view to check Force Touch capability
private struct ForceTouchCapabilityChecker: UIViewRepresentable {
    let onCapabilityDetected: (Bool) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCapabilityDetected: onCapabilityDetected)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        let supportsForceTouch = uiView.traitCollection.forceTouchCapability == .available
        context.coordinator.update(supportsForceTouch: supportsForceTouch)
    }
    
    final class Coordinator {
        let onCapabilityDetected: (Bool) -> Void
        private var lastSupportsForceTouch: Bool?
        
        init(onCapabilityDetected: @escaping (Bool) -> Void) {
            self.onCapabilityDetected = onCapabilityDetected
        }
        
        func update(supportsForceTouch: Bool) {
            guard lastSupportsForceTouch != supportsForceTouch else { return }
            lastSupportsForceTouch = supportsForceTouch
            onCapabilityDetected(supportsForceTouch)
        }
    }
}

extension View {
    /// Adds Force Press detection with long press fallback
    func onForcePress(perform action: @escaping () -> Void) -> some View {
        modifier(ForcePressModifier(onForcePress: action))
    }
}
