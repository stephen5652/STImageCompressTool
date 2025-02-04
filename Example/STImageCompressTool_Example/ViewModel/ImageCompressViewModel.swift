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
        let reloadDataDriver = input.reloadDataRelay
            .do(onNext: { (assets, shouldClear) in
                let newItems = assets.map { ImageItem(asset: $0, compressedImageURL: nil) }
                if shouldClear {
                    imageItemsRelay.accept(newItems)
                } else {
                    imageItemsRelay.accept(imageItemsRelay.value + newItems)
                }
            })
            .map { _ in return () }
            .asDriver(onErrorJustReturn: ())
        
        // 处理单个图片压缩更新
        let updateImageDriver = input.updateImageRelay
            .withLatestFrom(imageItemsRelay) { (updatedItems, currentItems) -> ([IndexPath], [ImageItem]) in
                var newItems = currentItems
                var updatedIndexPaths: [IndexPath] = []
                
                for item in updatedItems {
                    if let idx = currentItems.firstIndex(where: { $0.identifier == item.identifier }) {
                        newItems[idx] = item
                        updatedIndexPaths.append(IndexPath(row: idx, section: 0))
                    }
                }
                
                return (updatedIndexPaths, newItems)
            }
            .do(onNext: { _, items in
                imageItemsRelay.accept(items)
            })
            .map { indexPaths, _ in indexPaths }
            .asDriver(onErrorDriveWith: .empty())
        
        return Output(
            imageItems: imageItemsRelay.asObservable(),
            showImagePicker: input.selectImageRelay.asDriver(onErrorJustReturn: ()),
            reloadData: reloadDataDriver,
            reloadIndexPaths: updateImageDriver
        )
    }
} 
