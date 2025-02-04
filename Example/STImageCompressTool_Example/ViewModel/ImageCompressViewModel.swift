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
        let updateImageRelay: PublishRelay<[ImageItem]>
        let reloadDataRelay: PublishRelay<([PHAsset], Bool)>
    }
    
    struct Output {
        let imageItems: Observable<[ImageItem]>
        let showImagePicker: Driver<Void>
        let reloadData: Driver<Void>
        let reloadIndexPaths: Driver<[IndexPath]>
    }
    
    private let disposeBag = DisposeBag()
    
    func transform(_ input: Input) -> Output {
        let imageItemsRelay = BehaviorRelay<[ImageItem]>(value: [])
        
        // 处理选择图片
        input.reloadDataRelay
            .map { (assets, shouldClear) -> [ImageItem] in
                let newItems = assets.map { ImageItem(asset: $0, compressedImageURL: nil) }
                if shouldClear {
                    return newItems
                } else {
                    return imageItemsRelay.value + newItems
                }
            }
            .bind(to: imageItemsRelay)
            .disposed(by: disposeBag)
        
        let reloadDataDriver = input.reloadDataRelay
                .map { _ in return () }  // 触发全局刷新
                .asDriver(onErrorJustReturn: ())  // 转换为 Driver，并提供一个默认值
        
        // 处理图片压缩更新
        input.updateImageRelay
            .withLatestFrom(imageItemsRelay) { (updatedItems, currentItems) -> [ImageItem] in
                var newItems = currentItems
                for updatedItem in updatedItems {
                    if let index = currentItems.firstIndex(where: { $0.identifier == updatedItem.identifier }) {
                        newItems[index] = updatedItem
                    }
                }
                return newItems
            }
            .bind(to: imageItemsRelay)
            .disposed(by: disposeBag)
        
        // 更新数组
        let updateImageDriver = input.updateImageRelay
            .map { itemsArr in
                var result = [IndexPath]()
                let oldItems = imageItemsRelay.value
                var newItems = imageItemsRelay.value
                for item in itemsArr {
                    if let idx = oldItems.firstIndex(where: { $0 == item }) {
                        newItems[idx] = item
                        result.append(IndexPath(row: idx, section: 0))
                    }
                }
                imageItemsRelay.accept(newItems)
                
                return result
            }
            .asDriver(onErrorDriveWith: .empty())
        
        return Output(
            imageItems: imageItemsRelay.asObservable(),
            showImagePicker: input.selectImageRelay.asDriver(onErrorJustReturn: ()),
            reloadData: reloadDataDriver,
            reloadIndexPaths: updateImageDriver
        )
    }
} 
