//
//  model.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 27/9/25.
//

import Foundation

struct ProductList: Codable {
    let totalSize: Int
    let typeId: Int
    let offset: Int
    let products: [Product]

    enum CodingKeys: String, CodingKey {
        case offset, products
        case totalSize = "total_size"
        case typeId = "type_id"
    }
}

struct Product: Codable, Hashable {
    let id: Int
    let name: String
    let description: String
    let price: Int
    let stars: Int
    let img: String
    let location: String
    let createdAt: String
    let updatedAt: String
    let typeId: Int
    
    let imageWidth: Int?
    let imageHeight: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description, price, stars, img, location
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case typeId = "type_id"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
    }
}


