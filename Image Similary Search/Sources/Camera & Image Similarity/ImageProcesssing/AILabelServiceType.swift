//
//  AIEmbeddingService.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 27/9/25.
//

//
//  AIEmbeddingService.swift
//  AI integration sample
//

import UIKit
import RxSwift
import CoreML

protocol AILabelServiceType {
    func extractLabel(from pixelBuffer: CVPixelBuffer) -> Observable<String>
    func extractLabel(from image: UIImage) -> Observable<String>
    
    // Mới: topK labels với confidence
    func extractTopLabels(from pixelBuffer: CVPixelBuffer, topK: Int, threshold: Double) -> Observable<[(String, Double)]>
    func extractTopLabels(from image: UIImage, topK: Int, threshold: Double) -> Observable<[(String, Double)]>
}

final class AILabelService: AILabelServiceType {
    private let model: MobileNetV2
    private let targetSize = 224  // Resnet50 input size
    
    init() {
        print("[Flow] 🤖 [AILabelService] Initializing MobileNetV2 model...")
        // Tối ưu: Sử dụng ANE (Neural Engine) để tăng tốc
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        do {
            self.model = try MobileNetV2(configuration: config)
            print("[Flow] ✅ [AILabelService] MobileNetV2 model loaded successfully (CPU only)")
        } catch {
            print("[Flow] ❌ [AILabelService] Failed to load model: \(error.localizedDescription)")
            fatalError("Failed to load MobileNetV2 model: \(error)")
        }
    }
    
    // MARK: - Predict từ CVPixelBuffer (label duy nhất)
    func extractLabel(from pixelBuffer: CVPixelBuffer) -> Observable<String> {
        return Observable.create { observer in
            let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
            let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
            print("[Flow] 🤖 [AILabelService] extractLabel from pixel buffer - Buffer: \(bufferWidth)x\(bufferHeight)")
            
            let startTime = Date()
            do {
                let input = MobileNetV2Input(image: pixelBuffer)
                let output = try self.model.prediction(input: input)
                let predictionTime = Date().timeIntervalSince(startTime)
                print("[Flow] ✅ [AILabelService] Label extracted: '\(output.classLabel)' in \(String(format: "%.3f", predictionTime))s")
                observer.onNext(output.classLabel)
                observer.onCompleted()
            } catch {
                let errorTime = Date().timeIntervalSince(startTime)
                print("[Flow] ❌ [AILabelService] Label extraction failed after \(String(format: "%.3f", errorTime))s: \(error.localizedDescription)")
                observer.onError(error)
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Predict từ UIImage (label duy nhất)
    func extractLabel(from image: UIImage) -> Observable<String> {
        print("[Flow] 🖼️ [AILabelService] extractLabel from UIImage - Image size: \(image.size)")
        guard let buffer = image.pixelBuffer(width: targetSize, height: targetSize) else {
            print("[Flow] ❌ [AILabelService] Failed to convert UIImage to pixel buffer")
            return Observable.error(
                NSError(domain: "AIEmbeddingService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
            )
        }
        return extractLabel(from: buffer)
    }
    
    // MARK: - TopK labels từ CVPixelBuffer
    func extractTopLabels(from pixelBuffer: CVPixelBuffer, topK: Int = 3, threshold: Double = 0.1) -> Observable<[(String, Double)]> {
        return Observable.create { observer in
            let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
            let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
            print("[Flow] 🤖 [AILabelService] Starting model prediction - Buffer: \(bufferWidth)x\(bufferHeight), topK: \(topK), threshold: \(threshold)")
            
            let startTime = Date()
            do {
                let input = MobileNetV2Input(image: pixelBuffer)
                print("[Flow] 🔄 [AILabelService] Running model prediction...")
                let output = try self.model.prediction(input: input)
                
                let predictionTime = Date().timeIntervalSince(startTime)
                print("[Flow] ✅ [AILabelService] Model prediction completed in \(String(format: "%.3f", predictionTime))s")
                print("[Flow] 📊 [AILabelService] Total class probabilities: \(output.classLabelProbs.count)")
                
                // Sắp xếp theo confidence giảm dần, lọc theo threshold
                let topLabels = output.classLabelProbs
                    .filter { $0.value >= threshold }
                    .sorted { $0.value > $1.value }
                    .prefix(topK)
                
                let filteredCount = output.classLabelProbs.filter { $0.value >= threshold }.count
                print("[Flow] 📊 [AILabelService] Labels above threshold (\(threshold)): \(filteredCount), Returning top \(min(topK, filteredCount))")
                
                let result = Array(topLabels)
                if let first = result.first {
                    print("[Flow] 🏆 [AILabelService] Top label: '\(first.key)' with confidence: \(String(format: "%.4f", first.value))")
                }
                
                observer.onNext(result)
                observer.onCompleted()
            } catch {
                let errorTime = Date().timeIntervalSince(startTime)
                print("[Flow] ❌ [AILabelService] Model prediction failed after \(String(format: "%.3f", errorTime))s: \(error.localizedDescription)")
                observer.onError(error)
            }
            return Disposables.create()
        }
    }
    
    // MARK: - TopK labels từ UIImage
    func extractTopLabels(from image: UIImage, topK: Int = 3, threshold: Double = 0.1) -> Observable<[(String, Double)]> {
        print("[Flow] 🖼️ [AILabelService] Converting UIImage to pixel buffer - Image size: \(image.size), Target: \(targetSize)x\(targetSize)")
        guard let buffer = image.pixelBuffer(width: targetSize, height: targetSize) else {
            print("[Flow] ❌ [AILabelService] Failed to convert UIImage to pixel buffer")
            return Observable.error(
                NSError(domain: "AIEmbeddingService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
            )
        }
        print("[Flow] ✅ [AILabelService] UIImage converted to pixel buffer successfully")
        return extractTopLabels(from: buffer, topK: topK, threshold: threshold)
    }
}
