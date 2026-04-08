////
////  CoreDataManager.swift
////  AI integration sample
////
////  Created by Nguyen Duc Hung on 28/9/25.
////
//
////
////  CoreDataManager.swift
////  AI integration sample
////
////  Created by Nguyen Duc Hung on 28/9/25.
////
//
//import UIKit
//import CoreData
//import RxSwift
//
//final class ProductCoreDataService {
//    private let mainContext: NSManagedObjectContext
//    private let persistentContainer: NSPersistentContainer
//    private let vectorService: AIVectorServiceType
//    private let fileManager = FileManager.default
//
//    init(persistentContainer: NSPersistentContainer, vectorService: AIVectorServiceType) {
//        self.persistentContainer = persistentContainer
//        self.mainContext = persistentContainer.viewContext
//        self.vectorService = vectorService
//    }
//
//    // MARK: - Fetch All Products
//    func fetchAllProducts() -> Observable<[ProductItem]> {
//        return Observable.create { observer in
//            let context = self.persistentContainer.viewContext
//            context.perform {
//                let request: NSFetchRequest<ProductItem> = ProductItem.fetchRequest()
//                do {
//                    let items = try context.fetch(request)
//                    observer.onNext(items)
//                    observer.onCompleted()
//                } catch {
//                    observer.onError(error)
//                }
//            }
//            return Disposables.create()
//        }
//    }
//
//    // MARK: - Save Products
//    func saveProducts(_ products: [Product]) -> Observable<Void> {
//        let scheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)
//
//        print("📝 Start saving \(products.count) products to Core Data")
//
//        return Observable.from(products)
//            .flatMap { product in
//                self.processProduct(product)
//                    .subscribe(on: scheduler)
//            }
//            .toArray()
//            .map { _ in () }
//            .asObservable()
//            .do(onCompleted: {
//                print("✅ Finished saving all products")
//            })
//    }
//
//    // MARK: - Process Single Product
//    private func processProduct(_ product: Product) -> Observable<Void> {
//        guard let url = URL(string: APIConfig.baseURLString + "/uploads/" + product.img) else {
//            print("❌ Invalid URL for product id \(product.id)")
//            return Observable.empty()
//        }
//
//        return URLSession.shared.rx.data(request: URLRequest(url: url))
//            .flatMap { data -> Observable<Void> in
//                guard let image = UIImage(data: data) else {
//                    print("❌ Failed to create UIImage for product id \(product.id)")
//                    return Observable.empty()
//                }
//
//                // 1️⃣ Lưu ảnh vào Caches
//                self.saveImageToCaches(image: image, productId: product.id)
//
//                // 2️⃣ Lấy vector feature
//                return self.vectorService.extractFeaturePrint(from: image)
//                    .flatMap { featureData in
//                        // 3️⃣ Lưu vector vào Core Data
//                        self.saveVectorToCoreData(product: product, featureData: featureData)
//                    }
//            }
//    }
//
//    // MARK: - Save Image to Caches
//    private func saveImageToCaches(image: UIImage, productId: Int) {
//        guard let data = image.jpegData(compressionQuality: 0.8) else {
//            print("❌ Cannot convert UIImage to JPEG data")
//            return
//        }
//
//        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
//        let imageURL = cachesURL.appendingPathComponent("\(productId).jpg")
//
//        do {
//            try data.write(to: imageURL, options: .atomic)
//            print("💾 Saved image for product id \(productId) to Caches")
//        } catch {
//            print("❌ Error saving image for product id \(productId): \(error)")
//        }
//    }
//
//    // MARK: - Save Vector to Core Data
//    private func saveVectorToCoreData(product: Product, featureData: Data) -> Observable<Void> {
//        return Observable.create { observer in
//            guard !featureData.isEmpty else {
//                print("❌ Feature data is empty, skipping save for product id \(product.id)")
//                observer.onCompleted()
//                return Disposables.create()
//            }
//
//            let context = self.persistentContainer.newBackgroundContext()
//            context.perform {
//                let request: NSFetchRequest<ProductItem> = ProductItem.fetchRequest()
//                request.predicate = NSPredicate(format: "id == %d", product.id)
//                request.fetchLimit = 1
//
//                let item: ProductItem
//                if let existing = try? context.fetch(request).first {
//                    item = existing
//                    print("♻️ Updating existing ProductItem id \(product.id)")
//                } else {
//                    item = ProductItem(context: context)
//                    print("🆕 Creating new ProductItem id \(product.id)")
//                }
//
//                // Gán dữ liệu
//                item.id = Int64(product.id)
//                item.name = product.name
//                item.descriptionText = product.description
//                item.price = Int64(product.price)
//                item.stars = Int16(product.stars)
//                item.img = product.img
//                item.location = product.location
//                item.createdAt = ISO8601DateFormatter().date(from: product.createdAt) ?? Date()
//                item.updatedAt = ISO8601DateFormatter().date(from: product.updatedAt) ?? Date()
//                item.typeId = Int16(product.typeId)
//                item.imageWidth = Int16(product.imageWidth ?? 0)
//                item.imageHeight = Int16(product.imageHeight ?? 0)
//                item.featureVector = featureData
//
//                // 🔹 In ra các trường để theo dõi
//                print("""
//                📝 Product Saved:
//                id: \(item.id)
//                name: \(item.name ?? "")
//                price: \(item.price)
//                stars: \(item.stars)
//                featureVector size: \(item.featureVector?.count ?? 0) bytes
//                """)
//
//                do {
//                    try context.save()
//                    print("✅ Successfully saved vector for product id \(product.id)")
//                    observer.onNext(())
//                    observer.onCompleted()
//                } catch {
//                    print("❌ Error saving vector for product id \(product.id): \(error)")
//                    observer.onError(error)
//                }
//            }
//            return Disposables.create()
//        }
//    }
//
//    // MARK: - Get Image from Caches
//    func getImageFromCaches(productId: Int) -> UIImage? {
//        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
//        let imageURL = cachesURL.appendingPathComponent("\(productId).jpg")
//        guard let data = try? Data(contentsOf: imageURL) else { return nil }
//        return UIImage(data: data)
//    }
//}
