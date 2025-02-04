import UIKit
import RxSwift
import RxCocoa
import RxRelay
import Photos
import STImageCompressTool

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
    private var disposeBag = DisposeBag()
    var onCompressComplete: ((ImageItem) -> Void)?
    private let item: ImageItem
    private let autoCompressRelay = PublishRelay<Void>()
    
    // MARK: - Initialization
    init(item: ImageItem, onCompressComplete: ((ImageItem) -> Void)? = nil) {
        self.item = item
        self.asset = item.asset
        self.compressedImageURLRelay = BehaviorRelay(value: item.compressedImageURL)
        self.isCompressedRelay = BehaviorRelay(value: item.isCompressed)
        self.onCompressComplete = onCompressComplete
        
        // 如果未压缩，延迟触发自动压缩
        if !item.isCompressed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.autoCompressRelay.accept(())
            }
        }
    }
    
    // MARK: - Transform
    func transform(_ input: Input) -> Output {
        // 加载原始图片
        let originalImage = Observable<UIImage?>.create { [weak self] observer in
            guard let self = self else { return Disposables.create() }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false  // 异步加载
            
            // 在后台队列执行图片请求
            DispatchQueue.global(qos: .userInitiated).async {
                PHImageManager.default().requestImage(
                    for: self.asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, info in
                    observer.onNext(image)
                    observer.onCompleted()
                }
            }
            
            return Disposables.create()
        }
        .share(replay: 1)
        .observe(on: MainScheduler.instance)  // 确保在主线程传递结果
        
        // 加载压缩后的图片
        let compressedImage = compressedImageURLRelay
            .flatMap { url -> Observable<UIImage?> in
                guard let url = url else { return .just(nil) }
                return Observable.create { observer in
                    // 在后台队列加载图片
                    DispatchQueue.global(qos: .userInitiated).async {
                        let image = UIImage(contentsOfFile: url.path)
                        observer.onNext(image)
                        observer.onCompleted()
                    }
                    return Disposables.create()
                }
            }
            .share(replay: 1)
            .observe(on: MainScheduler.instance)  // 确保在主线程传递结果
        
        // 生成信息文本
        let infoText = Observable.combineLatest(
            originalImage,
            compressedImage
        )
        .flatMap { [weak self] original, compressed -> Observable<String> in
            guard let self = self else { return .just("") }
            
            return Observable.create { observer in
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self else { return }
                    var info = self.generateAssetInfo(prefix: "原图")
                    if let compressedImage = compressed {
                        info += "\n" + self.generateImageInfo(image: compressedImage, prefix: "压缩后")
                        if let time = item.compressedTime {
                            info += String(format: "\n压缩耗时: %.6f秒", time)
                        }
                    }
                    observer.onNext(info)
                    observer.onCompleted()
                }
                return Disposables.create()
            }
        }
        .observe(on: MainScheduler.instance)
        
        // 合并手动和自动压缩信号
        Observable.merge(
            input.compressButtonTap.asObservable(),
            autoCompressRelay.asObservable()
        )
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
        
        // 记录开始时间
        let startDate = Date()
        if let compressedData = STImageCompressTool.compress(image, toMaxFileSize: 500) {
            // 计算耗时
            let compressionTime = Date().timeIntervalSince(startDate)
            
            try? compressedData.write(to: tempURL)
            isCompressedRelay.accept(true)
            
            // 直接更新现有的 item
            var updatedItem = item
            updatedItem.compressedTime = compressionTime
            updatedItem.compressedImageURL = tempURL
            onCompressComplete?(updatedItem)
        }
    }
    
    private func generateAssetInfo(prefix: String) -> String {
        var info = "\(prefix)尺寸: \(asset.pixelWidth)x\(asset.pixelHeight)"
        
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first {
            let sizeOnDisk = resource.value(forKey: "fileSize") as? Int64 ?? 0
            info += "\n\(prefix)大小: \(String(format: "%.2f", Double(sizeOnDisk) / 1024.0))KB"
        }
        
        return info
    }
    
    private func generateImageInfo(image: UIImage, prefix: String) -> String {
        var info = "\(prefix)尺寸: \(Int(image.size.width))x\(Int(image.size.height))"
        
        // 在当前队列计算图片大小（因为已经在后台队列了）
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            info += "\n\(prefix)大小: \(String(format: "%.2f", Double(imageData.count) / 1024.0))KB"
        }
        
        return info
    }
} 
