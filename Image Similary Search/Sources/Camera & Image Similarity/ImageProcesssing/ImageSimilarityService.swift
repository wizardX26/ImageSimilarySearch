//
//  ImageSimilarityService.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 28/9/25.
//

//
//  ImageSimilarityService.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 28/9/25.
//

import UIKit
import CoreData
import RxSwift


final class ImageLabelMatchingService {
    private let labelService: AILabelServiceType
    private var searchCache: [String: [Product]] = [:]
    
    init(labelService: AILabelServiceType) {
        self.labelService = labelService
    }
    
    // Helper function để tạo hash cho ảnh - tối ưu với hash nhanh hơn
    private func getImageHash(_ image: UIImage) -> String {
        // Tối ưu: Sử dụng hash thay vì base64 để nhanh hơn
        guard let data = image.pngData() else { return UUID().uuidString }
        return String(data.hashValue)
    }
    
    func findMatchingProducts(
        from image: UIImage,
        in products: [Product],
        keyPath: String = "name"
    ) -> Observable<[Product]> {
        print("[Flow] 🔍 [ImageSimilarityService] ========== STARTING PRODUCT SEARCH ==========")
        print("[Flow] 📊 [ImageSimilarityService] Input - Image size: \(image.size), Products count: \(products.count), KeyPath: \(keyPath)")
        
        // Cache check - tối ưu với hash nhanh hơn
        let imageHash = getImageHash(image)
        print("[Flow] 🔑 [ImageSimilarityService] Image hash: \(imageHash)")
        
        if let cachedResults = searchCache[imageHash] {
            print("[Flow] 💾 [ImageSimilarityService] Cache hit! Returning \(cachedResults.count) cached products")
            return .just(cachedResults)
        }
        
        print("[Flow] 💾 [ImageSimilarityService] Cache miss - Processing new search")
        
        // Tối ưu: Pre-filter products để giảm dataset
        let filteredProducts = products.filter { product in
            // Chỉ search trong products có name không rỗng
            switch keyPath {
            case "name": return !product.name.isEmpty
            case "description": return !product.description.isEmpty
            default: return true
            }
        }
        
        print("[Flow] 🔍 [ImageSimilarityService] Filtered products: \(filteredProducts.count)/\(products.count) (keyPath: \(keyPath))")
        
        print("[Flow] 🤖 [ImageSimilarityService] Extracting label from image using AI model...")
        let labelStartTime = Date()
        return labelService.extractLabel(from: image)
            .do(onNext: { label in
                let labelTime = Date().timeIntervalSince(labelStartTime)
                print("[Flow] ✅ [ImageSimilarityService] Label extracted: '\(label)' in \(String(format: "%.3f", labelTime))s")
            })
            .map { [weak self] predictedLabel in
                guard let self = self else { return [] }
                print("[Flow] 🔄 [ImageSimilarityService] Processing label matching...")
                
                // Chuẩn hóa label → token
                let normalizedLabel = predictedLabel.ai_normalized()
                let labelTokens = normalizedLabel.ai_tokens().filter { !$0.isEmpty }
                print("[Flow] 🔤 [ImageSimilarityService] Label tokens: \(labelTokens)")
                
                if labelTokens.isEmpty {
                    print("[Flow] ⚠️ [ImageSimilarityService] No tokens extracted from label - returning empty results")
                    return []
                }

                print("[Flow] 🔍 [ImageSimilarityService] Matching tokens against \(filteredProducts.count) products...")
                let matchingStartTime = Date()
                
                // Duyệt sản phẩm đã filter, chuẩn hóa field và tính score
                let scored: [(Product, Int)] = filteredProducts.compactMap { product in
                    let fieldValue: String
                    switch keyPath {
                    case "name":
                        fieldValue = product.name
                    case "description":
                        fieldValue = product.description
                    default:
                        return nil
                    }

                    let normalizedField = fieldValue.ai_normalized()
                    let fieldTokens = Set(normalizedField.ai_tokens())

                    // Tính điểm: match theo token + bonus cho prefix/substring
                    var score = 0
                    for token in labelTokens {
                        if fieldTokens.contains(token) { score += 3 }
                        if normalizedField.hasPrefix(token) { score += 2 }
                        if normalizedField.contains(token) { score += 1 }
                    }

                    return score > 0 ? (product, score) : nil
                }

                let matchingTime = Date().timeIntervalSince(matchingStartTime)
                print("[Flow] 📊 [ImageSimilarityService] Matching completed in \(String(format: "%.3f", matchingTime))s - Found \(scored.count) products with scores > 0")

                // Tối ưu: Sắp xếp nhanh hơn với limit kết quả
                let results = scored
                    .sorted { (l, r) in
                        if l.1 != r.1 { return l.1 > r.1 }
                        return l.0.name.count < r.0.name.count
                    }
                    .prefix(20) // Chỉ lấy top 20 kết quả
                    .map { $0.0 }
                
                print("[Flow] 🏆 [ImageSimilarityService] Top results:")
                for (index, product) in results.enumerated() {
                    if let score = scored.first(where: { $0.0.id == product.id })?.1 {
                        print("[Flow]   \(index + 1). \(product.name) (score: \(score))")
                    }
                }
                
                // Cache results
                self.searchCache[imageHash] = results
                print("[Flow] 💾 [ImageSimilarityService] Cached \(results.count) results")
                
                print("[Flow] ✅ [ImageSimilarityService] ========== SEARCH COMPLETED ==========")
                return results
            }
    }
}

// MARK: - String helpers for normalization and tokenization
private extension String {
    func ai_normalized() -> String {
        return self
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func ai_tokens() -> [String] {
        // Tách theo ký tự không chữ và số; loại token rất ngắn
        let separators = CharacterSet.alphanumerics.inverted
        return self.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
    }
}
