import Foundation
import RxSwift
import RxCocoa
import UIKit
import Photos
import STImageCompressTool

struct ImageItem: Equatable {
    let asset: PHAsset
    let compressedImageURL: URL?
    let compressionDuration: TimeInterval?
    var isCompressed: Bool { compressedImageURL != nil }
    
    init(asset: PHAsset, compressedImageURL: URL? = nil, compressionDuration: TimeInterval? = nil) {
        self.asset = asset
        self.compressedImageURL = compressedImageURL
        self.compressionDuration = compressionDuration
    }
    
    // 实现 Equatable 协议
    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        // 同时比较 asset 和压缩状态
        return lhs.asset.localIdentifier == rhs.asset.localIdentifier &&
               lhs.isCompressed == rhs.isCompressed
    }
}

protocol ImageCompressViewModelType {
    func transform(_ input: ImageCompressViewModel.Input) -> ImageCompressViewModel.Output
}

class ImageCompressViewModel: ImageCompressViewModelType {
    
    struct Input {
        let selectImageRelay: PublishRelay<Void>
        let compressImageRelay: PublishRelay<Int>
        let selectedImageRelay: PublishRelay<[PHAsset]>
    }
    
    struct Output {
        let imageItems: Driver<[ImageItem]>
        let showImagePicker: Driver<Void>
    }
    
    private let imageManager = PHImageManager.default()
    private let disposeBag = DisposeBag()
    private let fileManager = FileManager.default
    
    // 创建临时目录用于存储压缩后的图片
    private lazy var tempDirectory: URL = {
        let tempPath = NSTemporaryDirectory()
        let directoryURL = URL(fileURLWithPath: tempPath).appendingPathComponent("CompressedImages")
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }()
    
    func transform(_ input: Input) -> Output {
        let imageItemsRelay = BehaviorRelay<[ImageItem]>(value: [])
        
        // 处理选择图片
        input.selectedImageRelay
            .do(onNext: { assets in
                print("🔵 Selected assets count: \(assets.count)")
            })
            .map { assets -> [ImageItem] in
                assets.map { ImageItem(asset: $0) }
            }
            .do(onNext: { items in
                print("🔵 New items created: \(items.count)")
            })
            // 使用 scan 操作符来累积数组
            .scan([]) { accumulated, new -> [ImageItem] in
                print("🔵 Accumulated: \(accumulated.count), New: \(new.count)")
                let combined = accumulated + new
                print("🔵 Combined total: \(combined.count)")
                return combined
            }
            .do(onNext: { items in
                print("🔵 Final items count: \(items.count)")
            })
            .bind(to: imageItemsRelay)
            .disposed(by: disposeBag)
        
        // 处理压缩图片
        input.compressImageRelay
            .do(onNext: { index in
                print("🔴 Compressing image at index: \(index)")
            })
            .withLatestFrom(imageItemsRelay) { index, items in (index, items) }
            .filter { index, items in index < items.count }
            .flatMapLatest { [weak self] index, items -> Observable<[ImageItem]> in
                guard let self = self else { return .just(items) }
                
                let item = items[index]
                return self.compressImage(asset: item.asset)
                    .map { compressedURL, duration -> [ImageItem] in
                        var newItems = items
                        newItems[index] = ImageItem(
                            asset: item.asset,
                            compressedImageURL: compressedURL,
                            compressionDuration: duration
                        )
                        print("🔴 Compressed image at index: \(index), duration: \(duration)s")
                        return newItems
                    }
                    .catchAndReturn(items)
            }
            .bind(to: imageItemsRelay)
            .disposed(by: disposeBag)
        
        return Output(
            imageItems: imageItemsRelay
                .do(onNext: { items in
                    print("🟢 Emitting items count: \(items.count)")
                })
                .asDriver(onErrorJustReturn: [])
                .distinctUntilChanged(),
            showImagePicker: input.selectImageRelay
                .do(onNext: { _ in
                    print("🟡 Show image picker triggered")
                })
                .asDriver(onErrorJustReturn: ())
        )
    }
    
    private func compressImage(asset: PHAsset) -> Observable<(URL, TimeInterval)> {
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onError(NSError(domain: "", code: -1))
                return Disposables.create()
            }
            
            let startTime = Date()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.version = .current
            
            let targetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            
            self.imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard let image = image else {
                    observer.onError(NSError(domain: "", code: -1))
                    return
                }
                
                DispatchQueue.global(qos: .userInitiated).async {
                    autoreleasepool {
                        guard let compressedData = STImageCompressTool.compress(image, toMaxFileSize: 500) else {
                            observer.onError(NSError(domain: "", code: -1))
                            return
                        }
                        
                        let compressedURL = self.tempDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("jpg")
                        
                        do {
                            try compressedData.write(to: compressedURL)
                            let duration = Date().timeIntervalSince(startTime)
                            observer.onNext((compressedURL, duration))
                            observer.onCompleted()
                        } catch {
                            observer.onError(error)
                        }
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    deinit {
        // 清理临时文件
        try? fileManager.removeItem(at: tempDirectory)
    }
} 
