////
////  AIVectorService.swift
////  AI integration sample
////
////  Created by Nguyen Duc Hung on 28/9/25.
////
//
//import UIKit
//import Vision
//import RxSwift
//
//protocol AIVectorServiceType {
//    func extractFeaturePrint(from pixelBuffer: CVPixelBuffer) -> Observable<Data>
//    func extractFeaturePrint(from image: UIImage) -> Observable<Data>
//    func compareFeaturePrint(_ data1: Data, _ data2: Data) throws -> Float
//}
//
//final class AIVectorService: AIVectorServiceType {
//    private let targetSize = 299
//    private let vectorQueue = DispatchQueue(label: "com.ai.vectorQueue", qos: .userInitiated)
//
//    // MARK: - Extract from CVPixelBuffer
//    func extractFeaturePrint(from pixelBuffer: CVPixelBuffer) -> Observable<Data> {
//        return Observable.create { [weak self] observer in
//            guard let self = self else { return Disposables.create() }
//
//            let request = VNGenerateImageFeaturePrintRequest { request, error in
//                if let error = error {
//                    let nsError = error as NSError
//                    // ✅ Sửa chỗ này: dùng VNErrorDomain + VNErrorCode.cancelled
//                    if nsError.domain == VNErrorDomain && nsError.code == VNErrorCode.requestCancelled.rawValue {
//                        observer.onNext(Data()) // trả về Data rỗng
//                        observer.onCompleted()
//                        return
//                    }
//                    observer.onError(error)
//                    return
//                }
//
//                guard let results = request.results as? [VNFeaturePrintObservation],
//                      let featurePrint = results.first else {
//                    observer.onError(NSError(domain: "AIVectorService",
//                                              code: -1,
//                                              userInfo: [NSLocalizedDescriptionKey: "No feature print found"]))
//                    return
//                }
//
//                do {
//                    let archivedData = try NSKeyedArchiver.archivedData(
//                        withRootObject: featurePrint,
//                        requiringSecureCoding: true
//                    )
//                    observer.onNext(archivedData)
//                    observer.onCompleted()
//                } catch {
//                    observer.onError(error)
//                }
//            }
//
//            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
//            self.vectorQueue.async {
//                do {
//                    try requestHandler.perform([request])
//                } catch {
//                    observer.onError(error)
//                }
//            }
//
//            return Disposables.create()
//        }
//    }
//
//    // MARK: - Extract from UIImage
//    func extractFeaturePrint(from image: UIImage) -> Observable<Data> {
//        guard let buffer = image.pixelBuffer(width: targetSize, height: targetSize) else {
//            return Observable.error(
//                NSError(domain: "AIVectorService",
//                        code: -1,
//                        userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
//            )
//        }
//        return extractFeaturePrint(from: buffer)
//    }
//
//    // MARK: - Compare two feature prints
////    func compareFeaturePrint(_ data1: Data, _ data2: Data) throws -> Float {
////        guard let obs1 = try NSKeyedUnarchiver.unarchivedObject(
////                ofClass: VNFeaturePrintObservation.self, from: data1),
////              let obs2 = try NSKeyedUnarchiver.unarchivedObject(
////                ofClass: VNFeaturePrintObservation.self, from: data2) else {
////            throw NSError(domain: "AIVectorService",
////                          code: -2,
////                          userInfo: [NSLocalizedDescriptionKey: "Failed to unarchive observations"])
////        }
////
////        var distance: Float = 0
////        try obs1.computeDistance(&distance, to: obs2)
////        return distance
////    }
//    
//    func compareFeaturePrint(_ data1: Data, _ data2: Data) throws -> Float {
//        guard !data1.isEmpty, !data2.isEmpty else {
//            throw NSError(domain: "AIVectorService",
//                          code: -3,
//                          userInfo: [NSLocalizedDescriptionKey: "One of the feature data is empty"])
//        }
//
//        guard let obs1 = try NSKeyedUnarchiver.unarchivedObject(
//                ofClass: VNFeaturePrintObservation.self, from: data1),
//              let obs2 = try NSKeyedUnarchiver.unarchivedObject(
//                ofClass: VNFeaturePrintObservation.self, from: data2) else {
//            throw NSError(domain: "AIVectorService",
//                          code: -2,
//                          userInfo: [NSLocalizedDescriptionKey: "Failed to unarchive observations"])
//        }
//
//        var distance: Float = 0
//        try obs1.computeDistance(&distance, to: obs2)
//        return distance
//    }
//}
