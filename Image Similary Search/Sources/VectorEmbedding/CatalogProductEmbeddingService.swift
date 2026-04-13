//
//  CatalogProductEmbeddingService.swift
//  Image Similary Search
//
//  Persists Fake Store API `Product` rows plus optional Vision feature vectors.
//

import UIKit
import CoreData
import RxSwift

/// Supply an implementation (e.g. Vision-based) when embeddings are required.
protocol ImageFeatureVectorExtracting: AnyObject {
    func extractFeaturePrint(from image: UIImage) -> Observable<Data>
}

final class CatalogProductEmbeddingService {
    private let persistentContainer: NSPersistentContainer
    private let vectorService: ImageFeatureVectorExtracting?
    private let fileManager = FileManager.default

    init(
        persistentContainer: NSPersistentContainer,
        vectorService: ImageFeatureVectorExtracting? = nil
    ) {
        self.persistentContainer = persistentContainer
        self.vectorService = vectorService
    }

    static func makePersistentContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "CatalogProduct")
        container.loadPersistentStores { _, error in
            if let error = error {
                assertionFailure("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }

    func fetchAll() -> Observable<[CatalogProduct]> {
        Observable.create { observer in
            let context = self.persistentContainer.viewContext
            context.perform {
                let request: NSFetchRequest<CatalogProduct> = CatalogProduct.fetchRequest()
                do {
                    let items = try context.fetch(request)
                    observer.onNext(items)
                    observer.onCompleted()
                } catch {
                    observer.onError(error)
                }
            }
            return Disposables.create()
        }
    }

    func saveProducts(_ products: [Product]) -> Observable<Void> {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)
        print("📝 Saving \(products.count) catalog products (metadata + optional embeddings)")
        return Observable.from(products)
            .concatMap { self.processProduct($0).subscribe(on: scheduler) }
            .toArray()
            .map { _ in () }
            .asObservable()
            .do(onCompleted: { print("✅ Finished saving catalog products") })
    }

    private func processProduct(_ product: Product) -> Observable<Void> {
        guard let url = URL(string: product.image), url.scheme == "http" || url.scheme == "https" else {
            print("❌ Invalid image URL for product id \(product.id)")
            return persist(product: product, featureData: nil)
        }

        return loadImageData(from: url)
            .flatMap { data -> Observable<Void> in
                guard let image = UIImage(data: data) else {
                    print("❌ Failed to decode UIImage for product id \(product.id)")
                    return self.persist(product: product, featureData: nil)
                }
                self.saveImageToCaches(image: image, productId: product.id)
                guard let vectorService = self.vectorService else {
                    return self.persist(product: product, featureData: nil)
                }
                return vectorService.extractFeaturePrint(from: image)
                    .flatMap { self.persist(product: product, featureData: $0) }
                    .catch { _ in self.persist(product: product, featureData: nil) }
            }
            .catch { error in
                print("❌ processProduct id \(product.id): \(error.localizedDescription)")
                return self.persist(product: product, featureData: nil)
            }
    }

    private func loadImageData(from url: URL) -> Observable<Data> {
        Observable.create { observer in
            let task = URLSession.shared.dataTask(with: url) { data, _, error in
                if let error = error {
                    observer.onError(error)
                    return
                }
                guard let data = data, !data.isEmpty else {
                    observer.onError(NSError(
                        domain: "CatalogProductEmbeddingService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Empty image response"]
                    ))
                    return
                }
                observer.onNext(data)
                observer.onCompleted()
            }
            task.resume()
            return Disposables.create { task.cancel() }
        }
    }

    private func saveImageToCaches(image: UIImage, productId: Int) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Cannot convert UIImage to JPEG data")
            return
        }
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let imageURL = cachesURL.appendingPathComponent("catalog_\(productId).jpg")
        do {
            try data.write(to: imageURL, options: .atomic)
            print("💾 Cached image for catalog product id \(productId)")
        } catch {
            print("❌ Error caching image id \(productId): \(error)")
        }
    }

    private func persist(product: Product, featureData: Data?) -> Observable<Void> {
        Observable.create { observer in
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                let request: NSFetchRequest<CatalogProduct> = CatalogProduct.fetchRequest()
                request.predicate = NSPredicate(format: "id == %lld", Int64(product.id))
                request.fetchLimit = 1

                let item: CatalogProduct
                if let existing = try? context.fetch(request).first {
                    item = existing
                } else {
                    item = CatalogProduct(context: context)
                }

                item.id = Int64(product.id)
                item.title = product.title
                item.price = product.price
                item.descriptionText = product.description
                item.category = product.category
                item.imageURL = product.image
                item.ratingRate = product.rating.rate
                item.ratingCount = Int32(product.rating.count)
                if let data = featureData, !data.isEmpty {
                    item.featureVector = data
                }

                do {
                    try context.save()
                    observer.onNext(())
                    observer.onCompleted()
                } catch {
                    print("❌ Core Data save failed id \(product.id): \(error)")
                    observer.onError(error)
                }
            }
            return Disposables.create()
        }
    }

    func getImageFromCaches(productId: Int) -> UIImage? {
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let imageURL = cachesURL.appendingPathComponent("catalog_\(productId).jpg")
        guard let data = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: data)
    }
}

extension CatalogProduct {
    /// Maps stored entity back to the API/domain `Product` (feature vector is not represented).
    func toProduct() -> Product {
        Product(
            id: Int(id),
            title: title ?? "",
            price: price,
            description: descriptionText ?? "",
            category: category ?? "",
            image: imageURL ?? "",
            rating: ProductRating(rate: ratingRate, count: Int(ratingCount))
        )
    }
}
