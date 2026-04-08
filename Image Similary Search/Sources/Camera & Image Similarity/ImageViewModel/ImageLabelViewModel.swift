

import UIKit
import RxSwift
import RxCocoa

enum SearchTimeoutError: Error {
    case timeout
}

final class ImageProcessingViewModel {

    // MARK: - Input
    let classifyTrigger = PublishRelay<UIImage>()
    let stopCameraTrigger = PublishRelay<Void>()
    let pixelBufferStream = PublishRelay<CVPixelBuffer>()

    // MARK: - Output
    let classifiedLabel: Driver<String>
    let confidenceLabel: Driver<String>
    let topLabels: PublishRelay<[(String, Double)]> = PublishRelay()
    let isProcessing: Driver<Bool>
    let error: Driver<String>

    let searchTrigger = PublishRelay<UIImage>()
    let showHintTrigger = PublishRelay<Void>()
    let isCameraRunning = BehaviorRelay<Bool>(value: false)


    // MARK: - Private
    private let aiService: AILabelServiceType
    private let disposeBag = DisposeBag()
    private var processingDisposable: Disposable?

    private let targetWidth = 224
    private let targetHeight = 224

    var cameraStartTime = Date()
    private let hintDelay: TimeInterval = 2.8 // ✅ đúng yêu cầu

     let isProcessingModel = BehaviorRelay<Bool>(value: false)
    private let didStartProcessing = BehaviorRelay<Bool>(value: false)

    private let activity = ActivityIndicator()
    private let errorTracker = PublishSubject<Error>()
    private let classifiedLabelSubject = PublishRelay<String>()
    private let confidenceLabelSubject = PublishRelay<String>()

    private let cancelProcessingTrigger = PublishRelay<Void>() // 🚨 trigger hủy classification

    init(aiService: AILabelServiceType = AILabelService()) {
        self.aiService = aiService
        self.isCameraRunning.accept(true)


        self.classifiedLabel = classifiedLabelSubject.asDriver(onErrorJustReturn: "Cannot classify")
        self.confidenceLabel = confidenceLabelSubject.asDriver(onErrorJustReturn: "")
        self.isProcessing = activity.asDriver()
        self.error = errorTracker
            .map { $0.localizedDescription }
            .asDriver(onErrorJustReturn: "Unknown error")

        setupCameraProcessing()
        setupSearchTriggerWithTimeout()
        setupClassifyTrigger()
        setupStopCameraTrigger()
    }

    private func setupCameraProcessing() {
        print("[Flow] 🔧 [ImageProcessingViewModel] Setting up camera processing pipeline...")
        processingDisposable?.dispose()
        
        print("[Flow] ⏳ [ImageProcessingViewModel] Starting warmup timer (1.666s)...")
        let warmupTimer = Observable<Int>
            .timer(.milliseconds(1666), scheduler: MainScheduler.instance) // 🎯 Warmup 1.5 giây
                .take(1)
                .do(onNext: { _ in
                    print("[Flow] ✅ [ImageProcessingViewModel] Warmup completed - Starting frame processing")
                })

            let subscription = pixelBufferStream
            .skip(until: warmupTimer) // 🎯 Bắt đầu nhận frame sau warmup
                .observe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                .do(onNext: { buffer in
                    let width = CVPixelBufferGetWidth(buffer)
                    let height = CVPixelBufferGetHeight(buffer)
                    print("[Flow] 📸 [ImageProcessingViewModel] Processing frame after warmup - size: \(width)x\(height)")
                })
                .throttle(.milliseconds(500), scheduler: MainScheduler.instance)  // Giảm từ 333ms xuống 1000ms
                .do(onNext: { _ in
                    print("[Flow] ⏱️ [ImageProcessingViewModel] Frame passed throttle filter (500ms)")
                })
            .filter { [weak self] _ in
                guard let self = self else { return false }
                let allowed = self.isCameraRunning.value && !self.isProcessingModel.value
                if !allowed {
                    print("[Flow] 🚫 [ImageProcessingViewModel] Frame blocked - camera running: \(self.isCameraRunning.value), processing: \(self.isProcessingModel.value)")
                } else {
                    print("[Flow] ✅ [ImageProcessingViewModel] Frame passed camera/processing check")
                }
                return allowed
            }
            // Bảo đảm chắc chắn thời gian ≥ 1.5s kể từ cameraStartTime
            .filter { [weak self] _ in
                guard let self = self else { return false }
                let elapsed = Date().timeIntervalSince(self.cameraStartTime)
                let pass = elapsed >= 1.666
                if !pass {
                    print("[Flow] ⏳ [ImageProcessingViewModel] Dropped frame before 1.666s warmup (elapsed: \(String(format: "%.2f", elapsed))s)")
                } else {
                    print("[Flow] ✅ [ImageProcessingViewModel] Frame passed time check (elapsed: \(String(format: "%.2f", elapsed))s)")
                }
                return pass
            }
            .flatMapLatest { [weak self] buffer -> Observable<(CVPixelBuffer, [(String, Double)])> in
                guard let self = self else { return .empty() }
                print("[Flow] 🔍 [ImageProcessingViewModel] Starting classification with model...")

                let processingBuffer: CVPixelBuffer
                let bufferFormat = CVPixelBufferGetPixelFormatType(buffer)
                let bufferWidth = CVPixelBufferGetWidth(buffer)
                let bufferHeight = CVPixelBufferGetHeight(buffer)
                
                print("[Flow] 🔄 [ImageProcessingViewModel] Checking buffer format - Format: \(bufferFormat), Size: \(bufferWidth)x\(bufferHeight), Target: \(self.targetWidth)x\(self.targetHeight)")
                
                if bufferFormat != kCVPixelFormatType_32BGRA ||
                   bufferWidth != self.targetWidth ||
                   bufferHeight != self.targetHeight {
                    print("[Flow] 🔄 [ImageProcessingViewModel] Converting and resizing buffer to \(self.targetWidth)x\(self.targetHeight)...")
                    guard let convertedBuffer = self.convertToBGRAAndResize(
                        pixelBuffer: buffer,
                        targetWidth: self.targetWidth,
                        targetHeight: self.targetHeight
                    ) else {
                        print("[Flow] ❌ [ImageProcessingViewModel] Failed to convert/resize buffer")
                        return .empty()
                    }
                    processingBuffer = convertedBuffer
                    print("[Flow] ✅ [ImageProcessingViewModel] Buffer converted successfully")
                } else {
                    print("[Flow] ✅ [ImageProcessingViewModel] Buffer already in correct format - no conversion needed")
                    processingBuffer = buffer
                }

                // Tối ưu: AI processing trên background thread để không block UI
                print("[Flow] 🤖 [ImageProcessingViewModel] Calling AI service to extract top labels (topK: 3, threshold: 0.1)...")
                let startTime = Date()
                return self.aiService
                    .extractTopLabels(from: processingBuffer, topK: 3, threshold: 0.1)
                    .observe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                    .do(onNext: { labels in
                        let inferenceTime = Date().timeIntervalSince(startTime)
                        print("[Flow] ✅ [ImageProcessingViewModel] Model inference completed in \(String(format: "%.3f", inferenceTime))s")
                        print("[Flow] 📊 [ImageProcessingViewModel] Top labels: \(labels.map { "\($0.0): \(String(format: "%.2f", $0.1))" }.joined(separator: ", "))")
                    })
                    .map { (processingBuffer, $0) }
                    .catch { error in
                        print("[Flow] ❌ [ImageProcessingViewModel] Model inference error: \(error.localizedDescription)")
                        self.errorTracker.onNext(error)
                        return .empty()
                    }
            }
            .filter { (_, topK) in
                guard let first = topK.first else {
                    print("[Flow] ⚠️ [ImageProcessingViewModel] No labels returned from model")
                    return false
                }
                let pass = first.1 > 0.33
                print("[Flow] \(pass ? "✅" : "❌") [ImageProcessingViewModel] Frame confidence check - Label: '\(first.0)', Confidence: \(String(format: "%.3f", first.1)) (threshold: 0.33)")
                return pass
            }
            .filter { [weak self] _ in
                // Chặn xử lý nếu đang processing
                guard let self = self else { return false }
                let canProcess = !self.isProcessingModel.value
                if !canProcess {
                    print("[Flow] 🚫 [ImageProcessingViewModel] Skipping frame - already processing model")
                } else {
                    print("[Flow] ✅ [ImageProcessingViewModel] Frame passed processing check")
                }
                return canProcess
            }
            .take(1) // 🎯 lấy ngay frame đầu tiên đủ điều kiện sau warmup
            .subscribe(onNext: { [weak self] (buffer, topK) in
                guard let self = self else { return }
                
                let elapsed = Date().timeIntervalSince(self.cameraStartTime)
                print("[Flow] 🎯 [ImageProcessingViewModel] ========== PROCESSING FIRST QUALIFYING FRAME ==========")
                print("[Flow] ⏱️ [ImageProcessingViewModel] Time elapsed since camera start: \(String(format: "%.3f", elapsed))s")
                print("[Flow] 📊 [ImageProcessingViewModel] Top labels: \(topK.map { "\($0.0): \(String(format: "%.2f", $0.1))" }.joined(separator: ", "))")
                
                self.isProcessingModel.accept(true) // 🚫 chặn frame tiếp theo khi đang xử lý
                print("[Flow] 🔒 [ImageProcessingViewModel] Set isProcessingModel = true to block further frames")
                
                self.topLabels.accept(topK)

                if let first = topK.first {
                    let label = first.0
                    let confidence = Int(first.1 * 100)
                    print("[Flow] 🏷️ [ImageProcessingViewModel] Updating UI labels - Label: '\(label)', Confidence: \(confidence)%")
                    self.classifiedLabelSubject.accept(label)
                    self.confidenceLabelSubject.accept("Confidence: \(confidence)%")
                }

                // Tối ưu: UIImage creation nhẹ, có thể chạy main thread
                if let uiImage = UIImage(pixelBuffer: buffer) {
                    print("[Flow] 🔗 [ImageProcessingViewModel] Converting buffer to UIImage - size: \(uiImage.size)")
                    print("[Flow] 🚀 [ImageProcessingViewModel] Emitting searchTrigger with classified image")
                    self.searchTrigger.accept(uiImage)
                } else {
                    print("[Flow] ❌ [ImageProcessingViewModel] Failed to create UIImage from pixel buffer")
                }
            })
        processingDisposable = subscription
        subscription.disposed(by: disposeBag)
    }

    private func setupSearchTriggerWithTimeout() {
        print("[Flow] ⏰ [ImageProcessingViewModel] Setting up searchTrigger with \(hintDelay)s timeout")

        let searchSignal = searchTrigger
            .do(onNext: { [weak self] image in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(self.cameraStartTime)
                print("[Flow] 🔍 [ImageProcessingViewModel] SearchSignal emitted - Image size: \(image.size), Elapsed: \(String(format: "%.3f", elapsed))s")
            })
            .map { _ in true }

        let timeoutSignal = Observable<Int>
            .timer(.milliseconds(Int(hintDelay * 1000)), scheduler: MainScheduler.instance)
            .do(onNext: { [weak self] _ in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(self.cameraStartTime)
                print("[Flow] ⏰ [ImageProcessingViewModel] Timeout triggered after \(self.hintDelay)s - Elapsed: \(String(format: "%.3f", elapsed))s")
            })
            .map { _ in false }

        print("[Flow] 🎯 [ImageProcessingViewModel] Waiting for searchSignal or timeout (\(hintDelay)s)...")
        Observable.amb([searchSignal, timeoutSignal])
            .take(1)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isSearchSuccess in
                guard let self = self else { return }
                
                let elapsed = Date().timeIntervalSince(self.cameraStartTime)
                print("[Flow] 🎯 [ImageProcessingViewModel] ========== TIMEOUT/SEARCH RESULT ==========")
                print("[Flow] ⏱️ [ImageProcessingViewModel] Total time elapsed: \(String(format: "%.3f", elapsed))s")
                
                if isSearchSuccess {
                    print("[Flow] ✅ [ImageProcessingViewModel] Search successful in \(String(format: "%.3f", elapsed))s - Triggering camera dismiss")
                    // Dismiss camera khi có kết quả trước timeout
                    self.stopCameraTrigger.accept(())
                } else {
                    print("[Flow] ⚠️ [ImageProcessingViewModel] Timeout reached - Showing hint for manual capture")
                    self.showHintTrigger.accept(())
                    // Camera VẪN CHẠY, user có thể chụp thủ công
                }
            })
            .disposed(by: disposeBag)
    }

    private func setupClassifyTrigger() {
        print("[Flow] 🔧 [ImageProcessingViewModel] Setting up classifyTrigger pipeline...")
        classifyTrigger
            .do(onNext: { image in
                print("[Flow] 📸 [ImageProcessingViewModel] classifyTrigger received image - size: \(image.size)")
            })
            .flatMapLatest { [weak self] image -> Observable<[(String, Double)]> in
                guard let self = self else { return .empty() }
                print("[Flow] 🤖 [ImageProcessingViewModel] Starting classification for manual capture image...")
                let startTime = Date()
                return self.aiService.extractTopLabels(from: image, topK: 3, threshold: 0.1)
                    .trackActivity(self.activity)
                    .do(onNext: { labels in
                        let inferenceTime = Date().timeIntervalSince(startTime)
                        print("[Flow] ✅ [ImageProcessingViewModel] Manual classification completed in \(String(format: "%.3f", inferenceTime))s")
                        print("[Flow] 📊 [ImageProcessingViewModel] Labels: \(labels.map { "\($0.0): \(String(format: "%.2f", $0.1))" }.joined(separator: ", "))")
                    })
                    .take(until: self.cancelProcessingTrigger) // 🚨 hủy classification nếu timeout
                    .catch { error in
                        print("[Flow] ❌ [ImageProcessingViewModel] Classification error: \(error.localizedDescription)")
                        self.errorTracker.onNext(error)
                        return .empty()
                    }
            }
            .subscribe(onNext: { [weak self] topK in
                guard let self = self else { return }
                print("[Flow] 🏷️ [ImageProcessingViewModel] Updating UI with classification results")
                self.topLabels.accept(topK)
                if let first = topK.first {
                    let label = first.0
                    let confidence = Int(first.1 * 100)
                    print("[Flow] 📝 [ImageProcessingViewModel] Setting label: '\(label)', confidence: \(confidence)%")
                    self.classifiedLabelSubject.accept(label)
                    self.confidenceLabelSubject.accept("Confidence: \(confidence)%")
                } else {
                    print("[Flow] ⚠️ [ImageProcessingViewModel] No labels found - setting 'Cannot classify'")
                    self.classifiedLabelSubject.accept("Cannot classify")
                    self.confidenceLabelSubject.accept("")
                }
            })
            .disposed(by: disposeBag)
    }

    private func setupStopCameraTrigger() {
        stopCameraTrigger
            .delay(.milliseconds(300), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                print("[Camera] 🛑 stopCameraTrigger called → reset state")
                self.resetAllState()
            })
            .disposed(by: disposeBag)
    }

    func resetAllState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let oldCameraRunning = self.isCameraRunning.value
            let oldDidStartProcessing = self.didStartProcessing.value
            let oldIsProcessingModel = self.isProcessingModel.value
            
            print("[Flow] 🔄 [ImageProcessingViewModel] ========== RESETTING STATE ==========")
            print("[Flow] 📊 [ImageProcessingViewModel] Old state - cameraRunning: \(oldCameraRunning), didStartProcessing: \(oldDidStartProcessing), isProcessingModel: \(oldIsProcessingModel)")
            
            self.didStartProcessing.accept(false)
            self.isProcessingModel.accept(false)
            //self.isCameraRunning.accept(false)
            self.cameraStartTime = Date()
            
            print("[Flow] ✅ [ImageProcessingViewModel] State reset completed - New cameraStartTime: \(self.cameraStartTime)")
        }
    }
    
    func convertToBGRAAndResize(pixelBuffer: CVPixelBuffer, targetWidth: Int, targetHeight: Int) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var bgraPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            nil,
            targetWidth,
            targetHeight,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &bgraPixelBuffer
        )

        guard let outputBuffer = bgraPixelBuffer else { return nil }

        let scaleX = CGFloat(targetWidth) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let scaleY = CGFloat(targetHeight) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let resizedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        context.render(resizedImage, to: outputBuffer)
        return outputBuffer
    }
}

