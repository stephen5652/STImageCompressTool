import UIKit
import RxSwift
import RxCocoa
import RxRelay
import Photos
import STImageCompressTool

// 导入 ImageItem 所在的模块
import STImageCompressTool_Example

class ImageCompressCellViewModel {
    
    // MARK: - Input/Output
    struct Input {
        let compressButtonTap: Signal<Void>
    }
    
    struct Output {
        let originalImage: Driver<UIImage?>
        let compressedImage: Driver<UIImage?>
        let infoText: Driver<String>
        let isCompressButtonHidden: Driver<Bool>
    }
    
    // MARK: - Private Properties
    private let asset: PHAsset
    private let compressedImageURLRelay: BehaviorRelay<URL?>
    private let isCompressedRelay: BehaviorRelay<Bool>
    private let disposeBag = DisposeBag()
    var onCompressComplete: ((ImageItem) -> Void)?
    private let item: ImageItem
    
    // MARK: - Initialization
    init(item: ImageItem, onCompressComplete: ((ImageItem) -> Void)? = nil) {
        self.item = item
        self.asset = item.asset
        self.compressedImageURLRelay = BehaviorRelay(value: item.compressedImageURL)
        self.isCompressedRelay = BehaviorRelay(value: item.isCompressed)
        self.onCompressComplete = onCompressComplete
    }
    
    // MARK: - Transform
    func transform(_ input: Input) -> Output {
        // 加载原始图片
        let originalImage = Observable<UIImage?>.create { [weak self] observer in
            guard let self = self else { return Disposables.create() }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: self.asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                observer.onNext(image)
                observer.onCompleted()
            }
            
            return Disposables.create()
        }.share(replay: 1)
        
        // 加载压缩后的图片
        let compressedImage = compressedImageURLRelay
            .flatMap { url -> Observable<UIImage?> in
                guard let url = url else { return .just(nil) }
                return Observable.just(UIImage(contentsOfFile: url.path))
            }
            .share(replay: 1)
        
        // 生成信息文本
        let infoText = Observable.combineLatest(
            originalImage,
            compressedImage
        )
        .map { [weak self] original, compressed in
            guard let self = self else { return "" }
            var info = self.generateAssetInfo(prefix: "原图")
            if let compressedImage = compressed {
                info += "\n" + self.generateImageInfo(image: compressedImage, prefix: "压缩后")
            }
            return info
        }
        
        // 处理压缩按钮点击
        input.compressButtonTap
            .asObservable()
            .withLatestFrom(originalImage)
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] image in
                self?.handleCompressButtonTap(image: image)
            })
            .disposed(by: disposeBag)
        
        return Output(
            originalImage: originalImage.asDriver(onErrorJustReturn: nil),
            compressedImage: compressedImage.asDriver(onErrorJustReturn: nil),
            infoText: infoText.asDriver(onErrorJustReturn: ""),
            isCompressButtonHidden: isCompressedRelay.asDriver()
        )
    }
    
    // MARK: - Private Methods
    private func handleCompressButtonTap(image: UIImage) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        if let compressedData = STImageCompressTool.compress(image, toMaxFileSize: 500) {
            try? compressedData.write(to: tempURL)
            isCompressedRelay.accept(true)
            
            // 直接更新现有的 item
            var updatedItem = item
            updatedItem.compressedImageURL = tempURL
            onCompressComplete?(updatedItem)
        }
    }
    
    private func generateAssetInfo(prefix: String) -> String {
        var info = "\(prefix)尺寸: \(asset.pixelWidth)x\(asset.pixelHeight)"
        
        // 获取文件大小
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first {
            let sizeOnDisk = resource.value(forKey: "fileSize") as? Int64 ?? 0
            info += "\n\(prefix)大小: \(String(format: "%.2f", Double(sizeOnDisk) / 1024.0))KB"
        }
        
        return info
    }
    
    private func generateImageInfo(image: UIImage, prefix: String) -> String {
        var info = "\(prefix)尺寸: \(Int(image.size.width))x\(Int(image.size.height))"
        
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            info += "\n\(prefix)大小: \(String(format: "%.2f", Double(imageData.count) / 1024.0))KB"
        }
        
        return info
    }
} 
