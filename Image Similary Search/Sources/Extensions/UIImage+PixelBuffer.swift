//
//  UIImage+PixelBuffer.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 28/9/25.
//

import UIKit
import CoreVideo
import AVFoundation

// Shared CIContext để tránh tạo mới liên tục
private let sharedCIContext = CIContext()

extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer) {
        // Chạy trên background thread để tránh block main thread
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = sharedCIContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        // Tạo UIImage với orientation đúng theo camera
        let orientation = UIImage.getImageOrientationFromCamera()
        self.init(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    private static func getImageOrientationFromCamera() -> UIImage.Orientation {
        // Lấy orientation từ MotionManager nếu có, fallback về .right
        if MotionManager.share.hasStableOrientation() {
            switch MotionManager.share.getOrientation() {
            case .portrait:
                return .right
            case .portraitUpsideDown:
                return .left
            case .landscapeLeft:
                return .up
            case .landscapeRight:
                return .down
            @unknown default:
                return .right
            }
        }
        return .right // Default: xoay 90° CW để đứng thẳng
    }
    
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }
        
        // Vẽ UIImage vào buffer (lật trục Y để khớp CoreGraphics)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
