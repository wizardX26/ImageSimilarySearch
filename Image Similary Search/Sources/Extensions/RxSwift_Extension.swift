//
//  RxSwift_Extension.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 29/9/25.
//

import UIKit
import Foundation
import RxSwift

// Thêm extension để theo dõi camera dismiss
extension Reactive where Base: UIViewController {
    var willDismiss: Observable<Void> {
        return methodInvoked(#selector(UIViewController.viewWillDisappear(_:)))
            .map { _ in }
    }
    
    var didDismiss: Observable<Void> {
        return methodInvoked(#selector(UIViewController.viewDidDisappear(_:)))
            .map { _ in }
    }
}
