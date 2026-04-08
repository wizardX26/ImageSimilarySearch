//
//  serview layer.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 27/9/25.
//

import Moya
import RxSwift
import RxMoya

protocol ProductServiceType {
    func fetchProducts(type: String) -> Single<[Product]>
}

class ProductService: ProductServiceType {
    private let provider = MoyaProvider<MyAPI>()
    
    func fetchProducts(type: String) -> Single<[Product]> {
        return provider.rx.request(.resource(category: "products", type: type))
            .filterSuccessfulStatusCodes()
            .map(ProductList.self)
            .map { $0.products }
    }
}
