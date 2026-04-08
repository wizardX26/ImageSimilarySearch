//
//  CameraGestureHandler.swift
//  AI integration sample
//
//  Created by AI Assistant on 28/9/25.
//

//
//  CameraGestureHandler.swift
//  AI integration sample
//
//  Created by AI Assistant on 28/9/25.
//

import UIKit
import AVFoundation

class CameraGestureHandler: NSObject {
    
    // MARK: - Properties
    private weak var cameraViewController: CameraViewController?
    private var panGesture: UIPanGestureRecognizer?
    private var isDismissing = false
    private var initialTranslation: CGFloat = 0
    private let dismissThreshold: CGFloat = 100 // Minimum distance to dismiss
    private let velocityThreshold: CGFloat = 500 // Minimum velocity to dismiss
    
    // MARK: - Initialization
    init(cameraViewController: CameraViewController) {
        self.cameraViewController = cameraViewController
        super.init()
        setupGestureRecognizer()
    }
    
    // MARK: - Setup
    private func setupGestureRecognizer() {
        guard let cameraVC = cameraViewController else { return }
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture?.delegate = self
        cameraVC.view.addGestureRecognizer(panGesture!)
        
        print("[Gesture] 🎯 Camera gesture handler initialized")
    }
    
    // MARK: - Gesture Handling
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let cameraVC = cameraViewController else { return }
        
        let translation = gesture.translation(in: cameraVC.view)
        let velocity = gesture.velocity(in: cameraVC.view)
        
        switch gesture.state {
        case .began:
            handlePanBegan(translationY: translation.y)
            
        case .changed:
            handlePanChanged(translationY: translation.y, velocityY: velocity.y)
            
        case .ended, .cancelled:
            handlePanEnded(translationY: translation.y, velocityY: velocity.y)
            
        default:
            break
        }
    }
    
    private func handlePanBegan(translationY: CGFloat) {
        // Chỉ cho phép dismiss khi kéo xuống
        if translationY > 0 {
            isDismissing = true
            initialTranslation = translationY
            print("[Gesture] 🎯 Pan began - potential dismiss")
        }
    }
    
    private func handlePanChanged(translationY: CGFloat, velocityY: CGFloat) {
        guard isDismissing else { return }
        
        let progress = min(translationY / 300, 1.0) // Max progress at 300 points
        let alpha = 1.0 - (progress * 0.5) // Fade to 50% opacity
        
        // Update camera view alpha
        cameraViewController?.view.alpha = alpha
        
        // Update camera view transform
        let scale = 1.0 - (progress * 0.1) // Slight scale down
        cameraViewController?.view.transform = CGAffineTransform(scaleX: scale, y: scale)
        
        print("[Gesture] 🎯 Pan changed - progress: \(progress)")
    }
    
    private func handlePanEnded(translationY: CGFloat, velocityY: CGFloat) {
        guard isDismissing else { return }
        
        let shouldDismiss = translationY > dismissThreshold || velocityY > velocityThreshold
        
        if shouldDismiss {
            // Dismiss camera
            print("[Gesture] 🎯 Pan ended - dismissing camera")
            cameraViewController?.dismiss(animated: true)
        } else {
            // Reset camera view
            print("[Gesture] 🎯 Pan ended - resetting camera")
            resetCameraView()
        }
        
        isDismissing = false
    }
    
    private func resetCameraView() {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: .curveEaseOut
        ) {
            self.cameraViewController?.view.alpha = 1.0
            self.cameraViewController?.view.transform = .identity
        }
    }
    
    // MARK: - Public Methods
    func cleanup() {
        if let gesture = panGesture {
            gesture.view?.removeGestureRecognizer(gesture)
        }
        panGesture = nil
        cameraViewController = nil
        print("[Gesture] 🧹 Camera gesture handler cleaned up")
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CameraGestureHandler: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Cho phép gesture khác hoạt động đồng thời
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Chỉ nhận gesture khi touch vào preview area (không phải buttons)
        guard let cameraVC = cameraViewController else { return false }
        
        let touchPoint = touch.location(in: cameraVC.view)
        let previewFrame = cameraVC.previewView.frame
        
        // Chỉ nhận gesture trong preview area
        return previewFrame.contains(touchPoint)
    }
}
