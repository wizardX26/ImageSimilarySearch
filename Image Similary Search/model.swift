//
//  model.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 27/9/25.
//

import Foundation

/// Fake Store API: https://fakestoreapi.com/products
struct ProductRating: Codable, Hashable {
    let rate: Double
    let count: Int
}

struct Product: Codable, Hashable {
    let id: Int
    let title: String
    let price: Double
    let description: String
    let category: String
    let image: String
    let rating: ProductRating
}
