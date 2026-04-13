
//
//  endpoints.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 27/9/25.
//

import Foundation
import Moya
import RxSwift

enum MyAPI {
    case products
}

enum APIConfig {
    static let baseURLString = "https://fakestoreapi.com"

    static var baseURL: URL {
        return URL(string: self.baseURLString)!
    }
}

extension MyAPI: TargetType {
    var baseURL: URL {
        return APIConfig.baseURL
    }
    
    var path: String {
        switch self {
        case .products:
            return "/products"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .products:
            return .get
        }
    }
    
    var task: Task {
        switch self {
        case .products:
            return .requestPlain
        }
    }
    
    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }
    
    var sampleData: Data {
        return Data()
    }
}
