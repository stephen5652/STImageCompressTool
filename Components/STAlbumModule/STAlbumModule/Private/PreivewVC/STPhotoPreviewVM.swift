//
//  STPhotoPreviewVM.swift
//  STAlbumModule
//
//  Created by stephen Li on 2025/2/12.
//

import STAllBase
import Photos
import RxSwift
import RxCocoa

class STPhotoPreviewVM: STViewModelProtocol {
    var disposeBag = DisposeBag()
    
    struct Input {
        let assetCollection: PHAssetCollection
        let currentIndex: IndexPath
    }
    
    struct Output {
        let photos: Observable<[PHAsset]>
    }
    
    func transformInput(_ input: Input) -> Output {
        // 获取相册中的所有照片
        let photos = Observable.create { observer -> Disposable in
            let assets = PHAsset.fetchAssets(in: input.assetCollection, options: nil)
            var photoArray: [PHAsset] = []
            
            assets.enumerateObjects { asset, _, _ in
                photoArray.append(asset)
            }
            
            // 数组逆序
            photoArray.reverse()
            
            observer.onNext(photoArray)
            observer.onCompleted()
            
            return Disposables.create()
        }
        
        return Output(photos: photos)
    }
}
