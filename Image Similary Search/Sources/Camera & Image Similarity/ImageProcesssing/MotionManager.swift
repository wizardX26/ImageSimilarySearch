//
//  MotionManager.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 27/9/25.
//

import Foundation
import AVFoundation
import CoreMotion


class MotionManager {
    static let share = MotionManager()
    let motionManager = CMMotionManager()
    var orientation: AVCaptureVideoOrientation = .portrait
    private(set) var hasReliableOrientation: Bool = false
    private var lastLoggedOrientation: AVCaptureVideoOrientation = .portrait
    func startMonitoringOrientation() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available.")
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.5

        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard let motion = motion, error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let gravity = motion.gravity
            let x = gravity.x
            let y = gravity.y

            if fabs(y) >= fabs(x) {
                self.orientation = y >= 0 ? .portraitUpsideDown : .portrait
            } else {
                self.orientation = x >= 0 ? .landscapeLeft : .landscapeRight
            }

            self.hasReliableOrientation = true

            // Chỉ log khi orientation thay đổi
            if self.orientation != self.lastLoggedOrientation {
                print("Physical orientation regardless of lock: \(self.orientation.rawValue)")
                self.lastLoggedOrientation = self.orientation
            }
        }
    }

    func getOrientation() -> AVCaptureVideoOrientation {
        return orientation
    }

    func hasStableOrientation() -> Bool {
        return hasReliableOrientation
    }

    func stopDeviceMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
