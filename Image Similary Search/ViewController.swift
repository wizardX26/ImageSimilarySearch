//
//  ViewController.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 23/9/25.
//

import UIKit
import RxSwift
import RxCocoa
import Kingfisher

final class ViewController: UIViewController {
    @IBOutlet weak var captureImage: UIImageView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var viewIncludeImage: UIView!
    @IBOutlet weak var imageCaptureLabel: UILabel!
    @IBOutlet weak var confidenceLabel: UILabel! // mới
    @IBOutlet weak var similarySearchLabel: UILabel!
    
    private var productVM: ProductViewModel!
    private let imageVM = ImageProcessingViewModel(aiService: AILabelService())
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupServices()
        setupUI()
        bindViewModels()

        // Tối ưu: Load data trên background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            DispatchQueue.main.async {
                self?.productVM.fetchTrigger.accept("")
            }
        }
    }

    private func setupServices() {
        let labelService = AILabelService()
        let labelMatchingService = ImageLabelMatchingService(labelService: labelService)

        productVM = ProductViewModel(
            service: ProductService(),
            labelMatchingService: labelMatchingService
        )
    }

    private func setupUI() {
        
        self.confidenceLabel.font = UIFont.italicSystemFont(ofSize: 16)
        self.confidenceLabel.textColor = #colorLiteral(red: 0, green: 0.5826650858, blue: 0.7529003024, alpha: 1)
        self.confidenceLabel.isHidden = true
        
        self.similarySearchLabel.font = UIFont.boldSystemFont(ofSize: 18)
        
        self.viewIncludeImage.clipsToBounds = true
        self.viewIncludeImage.layer.cornerRadius = 12
        self.viewIncludeImage.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        
        captureImage.contentMode = .scaleAspectFill
        captureImage.clipsToBounds = true
        captureImage.layer.cornerRadius = 8
        captureImage.backgroundColor = UIColor(white: 0.95, alpha: 1.0)

        collectionView.register(CollectionViewCell.nib,
                                forCellWithReuseIdentifier: CollectionViewCell.identifier)
        collectionView.rx.setDelegate(self).disposed(by: disposeBag)
    }

    private func bindViewModels() {
        // Hiển thị list hoặc kết quả search
        Observable.combineLatest(
            productVM.products.asObservable(),
            productVM.matchedProducts.asObservable(),
            productVM.hasSearched.asObservable()
        )
        .map { products, matchedProducts, hasSearched -> [Product] in
            if hasSearched {
                return matchedProducts
            } else {
                return products
            }
        }
        .bind(to: collectionView.rx.items(cellIdentifier: CollectionViewCell.identifier, cellType: CollectionViewCell.self)) { _, product, cell in
            // Tối ưu: Pre-compute URL và load image trên background
            let url = URL(string: product.image)
            // Tối ưu: Kingfisher với background processing
            KF.url(url)
                .placeholder(UIImage(named: "placeholder"))
//                .loadDiskFileSynchronously = false
//                .cacheMemoryOnly = false
//                .backgroundDecode = true
                .set(to: cell.imageView)
            cell.titleLabel.text = product.title
        }
        .disposed(by: disposeBag)

        // Matched products debug
        productVM.matchedProducts .drive(onNext: { matched in
            print("🔍 Found \(matched.count) matched products")
            self.similarySearchLabel.text = "Image Similary Search result: \(matched.count)"
        })
        .disposed(by: disposeBag)

        // Loading state
        productVM.isLoading
            .drive(onNext: { loading in
                print(loading ? "⏳ Loading..." : "✅ Done")
            })
            .disposed(by: disposeBag)

        // Error state
        productVM.error
            .drive(onNext: { errorMsg in
                print("❌ Error:", errorMsg)
            })
            .disposed(by: disposeBag)

        // Bind classifiedLabel → imageCaptureLabel
        imageVM.classifiedLabel
            .drive(imageCaptureLabel.rx.text)
            .disposed(by: disposeBag)

        // Bind confidenceLabel → confidenceLabel
        imageVM.confidenceLabel
            .drive(confidenceLabel.rx.text)
            .disposed(by: disposeBag)

        imageVM.confidenceLabel
            .map { $0 == "Confidence:" }
            .drive(confidenceLabel.rx.isHidden)
            .disposed(by: disposeBag)


        // Hiển thị ảnh capture lên UI
        imageVM.classifyTrigger
            .observe(on: MainScheduler.instance) // ✅ đảm bảo UI update trên main
            .bind(to: captureImage.rx.image)
            .disposed(by: disposeBag)

    }

    

    @IBAction func rightBarBtnTapped(_ sender: Any) {
        print("[Flow] 🚀 ========== BẮT ĐẦU FLOW TÌM KIẾM ẢNH ==========")
        print("[Flow] 📱 [ViewController] User tapped camera button - Opening camera...")
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let cameraVC = storyboard.instantiateViewController(
            withIdentifier: "CameraViewController"
        ) as? CameraViewController else {
            print("[Flow] ❌ [ViewController] Failed to instantiate CameraViewController")
            return
        }

        // **QUAN TRỌNG**: Reset state trước khi mở camera
        print("[Flow] 🔄 [ViewController] Resetting ImageProcessingViewModel state...")
        imageVM.resetAllState()
        imageVM.isCameraRunning.accept(true)
        print("[Flow] ✅ [ViewController] State reset completed, isCameraRunning = true")

        // Các binding - ĐẢM BẢO UI UPDATE TRÊN MAIN THREAD
        print("[Flow] 🔗 [ViewController] Setting up bindings...")
        
        cameraVC.capturedImage
            .compactMap { $0 }
            .do(onNext: { image in
                print("[Flow] 📸 [ViewController] Received captured image - size: \(image.size)")
            })
            .bind(to: imageVM.classifyTrigger)
            .disposed(by: disposeBag)

        cameraVC.capturedImage
            .compactMap { $0 }
            .observe(on: MainScheduler.instance) // ✅
            .do(onNext: { [weak self] image in
                print("[Flow] 🖼️ [ViewController] Updating UI with captured image")
                self?.captureImage.image = image
            })
            .map { image in image }
            .do(onNext: { image in
                print("[Flow] 🔍 [ViewController] Triggering product search with image")
            })
            .bind(to: productVM.searchTrigger)
            .disposed(by: disposeBag)

        // Ảnh cuối cùng sau dismiss → hiển thị nguyên trạng
        cameraVC.finalImage
            .observe(on: MainScheduler.instance)
            .bind(to: captureImage.rx.image)
            .disposed(by: disposeBag)
        
        cameraVC.pixelBufferStream
            .bind(to: imageVM.pixelBufferStream)
            .disposed(by: disposeBag)
        
        imageVM.searchTrigger
            .observe(on: MainScheduler.instance) // ✅ QUAN TRỌNG
            .do(onNext: { image in
                print("[Flow] 🎯 [ViewController] Received searchTrigger from ImageProcessingViewModel")
            })
            .map { image in image }
            .bind(to: productVM.searchTrigger)
            .disposed(by: disposeBag)

        print("[Flow] 📷 [ViewController] Presenting CameraViewController...")
        present(cameraVC, animated: true) {
            print("[Flow] ✅ [ViewController] CameraViewController presented successfully")
        }
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let itemsPerRow: CGFloat = 2
        let spacing: CGFloat = 8
        let totalSpacing = spacing * (itemsPerRow - 1)
        let width = (collectionView.bounds.width - totalSpacing) / itemsPerRow
        return CGSize(width: width, height: width * 1.2)
    }
}
