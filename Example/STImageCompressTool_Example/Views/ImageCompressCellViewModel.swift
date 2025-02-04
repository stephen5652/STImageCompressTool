import UIKit
import RxSwift
import RxCocoa
import RxRelay
import Photos

class ImageCompressCellViewModel {
    
    // MARK: - Input/Output
    struct Input {}
    
    struct Output {
        let originalImage: Driver<UIImage?>
        let compressedImage: Driver<UIImage?>
        let infoText: Driver<String>
    }
    
    // MARK: - Private Properties
    private let compressedImageURLRelay: BehaviorRelay<URL?>
    private var disposeBag = DisposeBag()
    private let item: ImageItem
    
    // MARK: - Initialization
    init(item: ImageItem) {
        self.item = item
        self.compressedImageURLRelay = BehaviorRelay(value: item.compressedImageURL)
    }
    
    // MARK: - Transform
    func transform(_ input: Input) -> Output {
        // 加载原始图片
        let originalImage = Observable<UIImage?>.create { [weak self] observer in
            guard let self = self,
                  let data = try? Data(contentsOf: item.orignalImageUrl)
            else { return Disposables.create() }
            
            let image = UIImage(data: data)
            
            observer.onNext(image)
            observer.onCompleted()
            
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
                            info += String(format: "\t压缩耗时: %.6f秒", time)
                        }
                    }
                    observer.onNext(info)
                    observer.onCompleted()
                }
                return Disposables.create()
            }
        }
        .observe(on: MainScheduler.instance)
        
        return Output(
            originalImage: originalImage.asDriver(onErrorJustReturn: nil),
            compressedImage: compressedImage.asDriver(onErrorJustReturn: nil),
            infoText: infoText.asDriver(onErrorJustReturn: "")
        )
    }
    
    // MARK: - Private Methods
    private func generateAssetInfo(prefix: String) -> String {
        var info = "\(prefix)尺寸: \(item.asset.pixelWidth)x\(item.asset.pixelHeight)"
        info += "\t\(prefix)大小: \(String(format: "%.2f", Double(item.imageFileSize) / 1024.0))KB"
        
        return info
    }
    
    private func generateImageInfo(image: UIImage, prefix: String) -> String {
        var info = "\(prefix)尺寸: \(Int(image.size.width))x\(Int(image.size.height))"
        
        // 在当前队列计算图片大小（因为已经在后台队列了）
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            info += "\t\(prefix)大小: \(String(format: "%.2f", Double(imageData.count) / 1024.0))KB"
        }
        
        return info
    }
} 
