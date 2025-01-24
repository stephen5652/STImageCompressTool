import Foundation
import RxSwift
import RxCocoa
import Photos
import STImageCompressTool



protocol ImageCompressViewModelType {
    func transform(_ input: ImageCompressViewModel.Input) -> ImageCompressViewModel.Output
}

class ImageCompressViewModel: ImageCompressViewModelType {
    
    struct Input {
        let selectImageRelay: PublishRelay<Void>
        let compressImageRelay: PublishRelay<Int>
        let selectedAssetsRelay: PublishRelay<[PHAsset]>
    }
    
    struct Output {
        let imageItems: Driver<[ImageItem]>
        let showImagePicker: Driver<Void>
    }
    
    private let disposeBag = DisposeBag()
    
    func transform(_ input: Input) -> Output {
        let imageItemsRelay = BehaviorRelay<[ImageItem]>(value: [])
        
        // 处理选择图片
        input.selectedAssetsRelay
            .map { assets in
                assets.map { ImageItem(asset: $0, compressedImageURL: nil) }
            }
            .map { newItems in
                imageItemsRelay.value + newItems
            }
            .bind(to: imageItemsRelay)
            .disposed(by: disposeBag)
        
        // 处理压缩图片
        input.compressImageRelay
            .withLatestFrom(imageItemsRelay) { index, items in (index, items) }
            .filter { index, items in index < items.count }
            .flatMap { index, items -> Observable<[ImageItem]> in
                let item = items[index]
                
                return Observable.create { observer in
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    
                    PHImageManager.default().requestImageDataAndOrientation(
                        for: item.asset,
                        options: options
                    ) { imageData, _, _, _ in
                        var newItems = items
                        
                        if let imageData = imageData,
                           let compressedData = STImageCompressTool.compress(UIImage(data: imageData)!, toMaxFileSize: 500) {
                            // 创建临时文件URL
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension("jpg")
                            
                            try? compressedData.write(to: tempURL)
                            newItems[index] = ImageItem(asset: item.asset, compressedImageURL: tempURL)
                        }
                        
                        observer.onNext(newItems)
                        observer.onCompleted()
                    }
                    
                    return Disposables.create()
                }
            }
            .bind(to: imageItemsRelay)
            .disposed(by: disposeBag)
        
        return Output(
            imageItems: imageItemsRelay.asDriver(),
            showImagePicker: input.selectImageRelay.asDriver(onErrorJustReturn: ())
        )
    }
} 
