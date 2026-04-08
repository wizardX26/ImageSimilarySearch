//
//  ViewModel.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 27/9/25.
//

import UIKit
import RxSwift
import RxCocoa
import RxRelay

final class ProductViewModel {
    let fetchTrigger = PublishRelay<String>()
    let searchTrigger = PublishRelay<UIImage>()

    let products: Driver<[Product]>
    private let matchedProductsRelay = BehaviorRelay<[Product]>(value: [])
    private let hasSearchedRelay = BehaviorRelay<Bool>(value: false)
    
    // Cache cho search results
    private var searchCache: [String: [Product]] = [:]

    var matchedProducts: Driver<[Product]> {
        return matchedProductsRelay.asDriver()
    }

    var hasSearched: Driver<Bool> {
        return hasSearchedRelay.asDriver()
    }

    let isLoading: Driver<Bool>
    let error: Driver<String>
    
    private let service: ProductServiceType
    private let labelMatchingService: ImageLabelMatchingService
    
    private let disposeBag = DisposeBag()

    init(
        service: ProductServiceType = ProductService(),
        labelMatchingService: ImageLabelMatchingService
    ) {
        self.service = service
        self.labelMatchingService = labelMatchingService
        
        let activity = ActivityIndicator()
        let errorTracker = PublishSubject<Error>()
        let productsSubject = BehaviorRelay<[Product]>(value: [])
        
        self.products = productsSubject.asDriver()
        self.isLoading = activity.asDriver()
        self.error = errorTracker
            .map { $0.localizedDescription }
            .asDriver(onErrorJustReturn: "Unknown error")
        
        // Fetch products từ backend
        fetchTrigger
            .flatMapLatest { type in
                service.fetchProducts(type: type)
                    .trackActivity(activity)
                    .do(onNext: { products in
                        productsSubject.accept(products)
                        self.hasSearchedRelay.accept(false) // Reset khi tải lại
                    })
                    .catch { error in
                        errorTracker.onNext(error)
                        return Observable.just([])
                    }
            }
            .subscribe()
            .disposed(by: disposeBag)
        
                // Tìm products bằng label từ ảnh → NSPredicate (tối ưu background processing)
                searchTrigger
                    .do(onNext: { image in
                        print("[Flow] 🔍 [ProductViewModel] ========== SEARCH TRIGGER RECEIVED ==========")
                        print("[Flow] 📸 [ProductViewModel] Search image - size: \(image.size)")
                    })
                    .filter { $0.size.width > 0 && $0.size.height > 0 }
                    .do(onNext: { [weak self] _ in
                        print("[Flow] ✅ [ProductViewModel] Image valid - Setting hasSearched = true")
                        self?.hasSearchedRelay.accept(true) // đánh dấu đã search
                    })
                    //.debounce(.milliseconds(99), scheduler: MainScheduler.instance)
                    .distinctUntilChanged()
                    .do(onNext: { image in
                        print("[Flow] 🔍 [ProductViewModel] Starting product search with image...")
                    })
                    .observe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated)) // Background processing
                    .flatMapLatest { [weak self] image -> Observable<[Product]> in
                        guard let self = self else { return .just([]) }
                        
                        let searchStartTime = Date()
                        
                        // Cache check
                        let imageHash = self.getImageHash(image)
                        print("[Flow] 🔑 [ProductViewModel] Image hash: \(imageHash)")
                        
                        if let cachedResults = self.searchCache[imageHash] {
                            print("[Flow] 💾 [ProductViewModel] Cache hit! Returning \(cachedResults.count) cached products")
                            return .just(cachedResults)
                        }
                        
                        print("[Flow] 💾 [ProductViewModel] Cache miss - Starting new search")
                        
                        let currentProducts = productsSubject.value
                        print("[Flow] 📊 [ProductViewModel] Searching in \(currentProducts.count) products...")
                        
                        return self.labelMatchingService
                            .findMatchingProducts(from: image, in: currentProducts)
                            .do(onNext: { results in
                                let searchTime = Date().timeIntervalSince(searchStartTime)
                                print("[Flow] ✅ [ProductViewModel] Search completed in \(String(format: "%.3f", searchTime))s")
                                print("[Flow] 🎯 [ProductViewModel] Found \(results.count) matching products")
                                
                                if results.isEmpty {
                                    print("[Flow] ⚠️ [ProductViewModel] No matching products found")
                                } else {
                                    print("[Flow] 📋 [ProductViewModel] Matching products:")
                                    for (index, product) in results.prefix(5).enumerated() {
                                        print("[Flow]   \(index + 1). \(product.name)")
                                    }
                                    if results.count > 5 {
                                        print("[Flow]   ... and \(results.count - 5) more")
                                    }
                                }
                                
                                // Cache results
                                self.searchCache[imageHash] = results
                                print("[Flow] 💾 [ProductViewModel] Cached \(results.count) results")
                            })
                            .catch { error in
                                let errorTime = Date().timeIntervalSince(searchStartTime)
                                print("[Flow] ❌ [ProductViewModel] Search error after \(String(format: "%.3f", errorTime))s: \(error.localizedDescription)")
                                return .just([])
                            }
                    }
                    .observe(on: MainScheduler.instance) // UI update về main thread
                    .do(onNext: { results in
                        print("[Flow] 🎨 [ProductViewModel] Updating UI with \(results.count) results on main thread")
                    })
                    .bind(to: matchedProductsRelay)
                    .disposed(by: disposeBag)
            }

            // Helper function để tạo hash cho ảnh - tối ưu với hash nhanh hơn
    private func getImageHash(_ image: UIImage) -> String {
        // Tối ưu: Sử dụng hash thay vì base64 để nhanh hơn
        guard let data = image.pngData() else { return UUID().uuidString }
        return String(data.hashValue)
    }
}

