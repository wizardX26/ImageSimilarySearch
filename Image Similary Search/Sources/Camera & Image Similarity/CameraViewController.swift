//
//  CameraViewController.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 23/9/25.
///  Revised by ChatGPT on 27/09/2025


import UIKit
import AVFoundation
import CoreMotion
import PhotosUI

import RxSwift
import RxCocoa

class CameraViewController: UIViewController, UIImagePickerControllerDelegate,
                            UINavigationControllerDelegate {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var rotateButton: UIButton!
    
    let showCaptureHint = PublishSubject<Void>()
    let finalImage = PublishSubject<UIImage>() // ảnh cuối cùng sau khi dismiss
    let imViewModel = ImageProcessingViewModel()

    
    private(set) var previewLayer: AVCaptureVideoPreviewLayer!
    private var captureSession: AVCaptureSession!
    private var photoOutput: AVCapturePhotoOutput!
    private var videoOutput: AVCaptureVideoDataOutput!
    
    // MARK: - Apple's Recommended Queue Structure
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private let frameQueue = DispatchQueue(label: "camera.frame.queue", qos: .userInitiated)
    private let videoQueue = DispatchQueue(label: "com.example.camera.videoQueue")
    
    // MARK: - Performance Optimization
    private var isSessionReady = false
    private let sessionReadySubject = PublishSubject<Bool>()
    
    // MARK: - Action State Management (Mutually Exclusive)
    private enum ActionState {
        case idle
        case frameProcessing
        case manualCapture
        case librarySelection
    }
    
    private var currentActionState: ActionState = .idle
    
    // MARK: - Gesture Handler
    private var gestureHandler: CameraGestureHandler?
    
    let capturedImage = PublishSubject<UIImage>()
    let pixelBufferStream = PublishSubject<CVPixelBuffer>()

    private var didAutoCapture = false
    private var manualCaptureRequested = false
    private var lastAutoImage: UIImage?

    private let disposeBag = DisposeBag()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[Flow] 📱 [CameraViewController] viewDidLoad - Initializing camera view controller")
        
        // Setup nút capture
        self.captureButton.setTitle("", for: .normal)
        captureButton.layer.cornerRadius = captureButton.frame.height / 2
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.clipsToBounds = true
        
        print("[Flow] 🔗 [CameraViewController] Setting up RxSwift bindings...")
        
        imViewModel.stopCameraTrigger
                .observe(on: MainScheduler.instance)
                .bind(onNext: { [weak self] in
                        print("[Camera VC] 📢✅ RECEIVED stopCameraTrigger via BIND!")
                        self?.stopCamera()
                        
                        // Reset state về idle khi camera dismiss
                        self?.currentActionState = .idle
                    })
                .disposed(by: disposeBag)
        
        imViewModel.showHintTrigger
            .observe(on: MainScheduler.instance)
            .bind(to: showCaptureHint)
            .disposed(by: disposeBag)

        
        // Subcribe để cập nhật UI khi nhận signal
        showCaptureHint
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.animationCaptureBtnHint()
            })
            .disposed(by: disposeBag)
    
        pixelBufferStream
            .do(onNext: { _ in
                print("[Flow] 📹 [CameraViewController] Emitting pixel buffer to ImageProcessingViewModel")
            })
            .bind(to: imViewModel.pixelBufferStream)
            .disposed(by: disposeBag)

        // Forward auto-selected frame and remember last frame for final oriented display
        imViewModel.searchTrigger
            .observe(on: MainScheduler.instance)
            .do(onNext: { [weak self] image in
                print("[Flow] 🎯 [CameraViewController] Received searchTrigger from ImageProcessingViewModel - image size: \(image.size)")
                // Chuyển sang frame processing state
                self?.currentActionState = .frameProcessing
            })
            .bind(to: capturedImage)
            .disposed(by: disposeBag)

    
        
        rotateButton.setTitle("", for: .normal)
        rotateButton.setImage(UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90"), for: .normal)
        rotateButton.clipsToBounds = true

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        checkCameraPermissions()
    }
    
    deinit {
        print("[Camera] 🧹 Deinit - cleaning up")
        captureSession?.stopRunning()
        MotionManager.share.stopDeviceMotionUpdates()
        
        // Cleanup gesture handler
        gestureHandler?.cleanup()
        gestureHandler = nil
    }
    
    private func stopCameraSession() {
        /// Chỉ dừng capture session, không dismiss view controller
        if captureSession != nil && captureSession.isRunning {
            captureSession.stopRunning()
            print("[Camera VC] 🛑 Camera session stopped by ViewModel request")
        }
        
        // Dừng motion updates
        MotionManager.share.stopDeviceMotionUpdates()
        
        // 🚨 KHÔNG dismiss view controller ở đây
    }
    
    func stopCamera() {
        /// Dừng session ngay lập tức
        if captureSession != nil && captureSession.isRunning {
            captureSession.stopRunning()
            print("[Camera] 🛑 Camera session stopped")
        }
        
        // Dừng motion updates
        MotionManager.share.stopDeviceMotionUpdates()
        
        // Dismiss nhẹ nhàng sau 0.66s
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Animation fade out trong 0.66s
            UIView.animate(withDuration: 0.66, animations: {
                self.view.alpha = 0
                self.view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }) { _ in
                // Emit final image (display-only) before dismiss
                if let image = self.lastAutoImage {
                    self.finalImage.onNext(image)
                }
                // Dismiss ngay lập tức sau animation
                self.dismiss(animated: false) {
                    print("[Camera] ✅ Camera dismissed with 0.66s fade animation")
                }
            }
        }
    }

    
    func animationCaptureBtnHint(repeatCount: Int = 3) {
        captureButton.isHidden = false
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.transform = .identity
        
        let pulseAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        pulseAnimation.values = [1.0, 1.3, 0.9, 1.05, 1.0]
        pulseAnimation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        pulseAnimation.duration = 0.8
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.repeatCount = Float(repeatCount)
        
        captureButton.layer.add(pulseAnimation, forKey: "pulseHint")
    }

    // MARK: - Actions
    @IBAction func captureButtonTapped(_ sender: Any) {
        // Kiểm tra state - chỉ cho phép chụp khi idle
        guard currentActionState == .idle else {
            print("[Capture] 🚫 Cannot capture - action in progress: \(currentActionState)")
            return
        }
        
        currentActionState = .manualCapture
        capturePhoto(manual: true)
    }

    @IBAction func libraryBtnTapped(_ sender: Any) {
        openPhotoLibrary()
    }
    
    @IBAction func rotateBtnTapped(_ sender: Any) {
        switchCamera()
    }
    
    // MARK: - Camera lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("[Flow] 👁️ [CameraViewController] viewWillAppear - Preparing camera session...")
        
        didAutoCapture = false
        manualCaptureRequested = false

        print("[Flow] 📐 [CameraViewController] Starting motion monitoring for orientation...")
        MotionManager.share.startMonitoringOrientation()
        
        self.imViewModel.cameraStartTime = Date()
        print("[Flow] ⏱️ [CameraViewController] Camera start time set: \(self.imViewModel.cameraStartTime)")
        
        // Apple's recommended approach: Use dedicated session queue
        if self.captureSession?.isRunning == false {
            print("[Flow] 🎬 [CameraViewController] Camera session not running - Starting setup...")
            // Setup preview layer trước khi start session để tránh màn hình trắng
            setupPreviewLayer()
            
            sessionQueue.async { [weak self] in
                guard let self = self else { return }
                print("[Flow] 🎥 [CameraViewController] Starting capture session on background queue...")
                self.captureSession.startRunning()
                
                // Wait for session to be ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.isSessionReady = true
                    self?.sessionReadySubject.onNext(true)
                    print("[Flow] ✅ [CameraViewController] Camera session ready after 0.05s")
                }
                
                DispatchQueue.main.async {
                    print("[Flow] ✅ [CameraViewController] Capture session started successfully")
                }
            }
        } else {
            print("[Flow] ℹ️ [CameraViewController] Camera session already running")
        }
        
        if gestureHandler == nil {
            print("[Flow] 👆 [CameraViewController] Initializing gesture handler...")
            gestureHandler = CameraGestureHandler(cameraViewController: self)
        }
    }
    
    // TRONG CameraViewController - SỬA LẠI
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // CHỈ stop session và motion, KHÔNG reset ViewModel state
        MotionManager.share.stopDeviceMotionUpdates()

        // Apple's recommended approach: Stop session on dedicated queue
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession?.isRunning == true else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                print("[Camera] 📷 Stopped capture session on dedicated queue")
            }
        }
    }
//
//    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
//
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        didAutoCapture = false
//        manualCaptureRequested = false
//
//        MotionManager.share.startMonitoringOrientation()
//        self.imViewModel.cameraStartTime = Date()
//
//        sessionQueue.async { [weak self] in
//            guard let self = self, self.captureSession?.isRunning == false else { return }
//            self.captureSession.startRunning()
//        }
//    }
//
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//
//        self.imViewModel.resetAllState()
//        MotionManager.share.stopDeviceMotionUpdates()
//
//        sessionQueue.async { [weak self] in
//            guard let self = self, self.captureSession?.isRunning == true else { return }
//            self.captureSession.stopRunning()
//        }
//    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
    }

    // MARK: - Permissions & Setup
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async { self?.setUpCamera() }
            }
        case .authorized:
            setUpCamera()
        default:
            break
        }
    }

    private func setUpCamera() {
        guard photoOutput == nil && videoOutput == nil else { return }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Input
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Camera input error: \(error)")
            return
        }

        // Photo output
        let photo = AVCapturePhotoOutput()
        photo.isHighResolutionCaptureEnabled = true
        if captureSession.canAddOutput(photo) {
            captureSession.addOutput(photo)
            photoOutput = photo
        }

        // Video data output
        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        // Apple's recommended approach: Use dedicated frame queue
        video.setSampleBufferDelegate(self, queue: frameQueue)
        if captureSession.canAddOutput(video) {
            captureSession.addOutput(video)
            videoOutput = video
        }

        DispatchQueue.main.async { [weak self] in
            self?.setupPreviewLayer()
        }
    }

    private func setupPreviewLayer() {
        guard previewLayer == nil else {
            print("[Flow] ℹ️ [CameraViewController] Preview layer already exists - updating frame")
            previewLayer.frame = previewView.bounds
            return
        }
        print("[Flow] 🎨 [CameraViewController] Creating preview layer...")
        // Apple's recommended approach: Setup preview layer ngay lập tức
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = previewView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        if let connection = previewLayer.connection {
            let orientation = MotionManager.share.getOrientation()
            connection.videoOrientation = orientation
            print("[Flow] 📐 [CameraViewController] Preview layer orientation set: \(orientation.rawValue)")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewView.layer.insertSublayer(self.previewLayer, at: 0)
            self.view.bringSubviewToFront(self.captureButton)
            self.previewView.layer.masksToBounds = true
            print("[Flow] ✅ [CameraViewController] Preview layer added to view on main thread")
        }
    }

    // MARK: - Capture Photo
    private func capturePhoto(manual: Bool = false) {
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        if let connection = photoOutput.connection(with: .video) {
            connection.videoOrientation = MotionManager.share.getOrientation()
        }
        if manual { manualCaptureRequested = true }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Camera control
    private func switchCamera() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
               let newInput = try? AVCaptureDeviceInput(device: newDevice),
               captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
            }
        }
    }

    // MARK: - Library picker
    private func openPhotoLibrary() {
        // Kiểm tra state - chỉ cho phép mở library khi idle
        guard currentActionState == .idle else {
            print("[Library] 🚫 Cannot open library - action in progress: \(currentActionState)")
            return
        }
        
        print("[Library] 📚 Opening photo library...")
        
        // Chuyển sang library state
        currentActionState = .librarySelection
        
        // Tạm dừng frame processing
        imViewModel.isProcessingModel.accept(true)
        
        if #available(iOS 14, *) {
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true, completion: nil)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            present(picker, animated: true, completion: nil)
        }
    }
    
    func stopStreaming() {
        if captureSession.isRunning {
                captureSession.stopRunning()
                print("[Camera] 🛑 Camera streaming stopped")
            }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("[Flow] ❌ [CameraViewController] Error processing photo: \(error.localizedDescription)")
            manualCaptureRequested = false
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("[Flow] ❌ [CameraViewController] Failed to create UIImage from photo data")
            manualCaptureRequested = false
            return
        }
        print("[Flow] 📸 [CameraViewController] Photo captured successfully - size: \(image.size)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("[Flow] 📤 [CameraViewController] Emitting captured image to capturedImage stream")
            self.capturedImage.onNext(image)  // <--- phát ảnh
            if self.manualCaptureRequested {
                print("[Flow] 👋 [CameraViewController] Manual capture requested - Dismissing camera...")
                self.manualCaptureRequested = false
                self.dismiss(animated: true)
            }
        }
    }
}
    
// MARK: - PHPickerViewControllerDelegate
extension CameraViewController: PHPickerViewControllerDelegate {
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            if let image = object as? UIImage {
                DispatchQueue.main.async {
                    self?.capturedImage.onNext(image)  // <--- phát ảnh
                    self?.stopCamera()
                }
            }
        }
    }
    
    // UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            print("[Library] 📚 Selected image from library")
            
            // Dismiss library ngay lập tức
            picker.dismiss(animated: true) { [weak self] in
                // Emit image và dismiss camera ngay
                self?.capturedImage.onNext(image)
                self?.currentActionState = .idle
                self?.stopCamera()
                
                // Dismiss camera ngay lập tức
                self?.dismiss(animated: true)
            }
        } else {
            // User cancel library - reset state
            picker.dismiss(animated: true) { [weak self] in
                print("[Library] 📚 User cancelled library selection")
                self?.currentActionState = .idle
                self?.imViewModel.isProcessingModel.accept(false)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            // User cancel library - reset state
            print("[Library] 📚 User cancelled library selection")
            self?.currentActionState = .idle
            self?.imViewModel.isProcessingModel.accept(false)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("[Flow] ⚠️ [CameraViewController] Failed to get pixel buffer from sample buffer")
            return
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("[Flow] 📹 [CameraViewController] Received video frame: \(width)x\(height) - Emitting to pixelBufferStream")
        pixelBufferStream.onNext(pixelBuffer)
    }
}

