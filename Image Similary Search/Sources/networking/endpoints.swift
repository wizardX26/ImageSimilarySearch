
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
    case resource(category: String, type: String)
}

enum APIConfig {
    #if targetEnvironment(simulator)
    static let baseURLString = "http://127.0.0.1:8000"
    #else
    static let baseURLString = "http://192.168.1.14:8000"
    #endif

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
        case .resource(let category, let type):
            return "/api/v1/\(category)/\(type)"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .resource:
            return .get
        }
    }
    
    var task: Task {
        switch self {
        case .resource:
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
