import Foundation
import RxSwift
import RxCocoa
import Photos
import STImageCompressTool
import STBaseModel

protocol ImageCompressViewModelType {
    func transform(_ input: ImageCompressViewModel.Input) -> ImageCompressViewModel.Output
}

class ImageCompressViewModel: ImageCompressViewModelType {
    
    struct Input {
        let selectImageRelay: PublishRelay<Void>
        let reloadDataRelay: PublishRelay<([PHAsset], Bool)>
    }
    
    struct Output {
        let imageItems: Driver<[ImageItem]>
        let showImagePicker: Driver<Void>
        let reloadData: Driver<Void>
        let reloadIndexPaths: Driver<[IndexPath]>
    }
    
    private let disposeBag = DisposeBag()
    
    func transform(_ input: Input) -> Output {
        let imageItemsRelay = BehaviorRelay<[ImageItem]>(value: [])
        let reloadDataRelay = BehaviorRelay<Void>(value: ())
        let updateImageDriver = BehaviorRelay<[IndexPath]>(value: [])
        
        // 处理选择图片
        input.reloadDataRelay
            .subscribe(onNext: { [weak self] (assets, shouldClear) in
                guard let self = self else { return }
                if shouldClear {
                    imageItemsRelay.accept([])
                    reloadDataRelay.accept(())
                    return
                }
                
                // 创建临时数组存储新项目
                var newItems: [ImageItem] = []
                let group = DispatchGroup()
                
                for asset in assets {
                    group.enter()
                    self.loadOriginalImage(asset) { item in
                        newItems.append(item)
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    // 一次性更新所有项目
                    imageItemsRelay.accept(imageItemsRelay.value + newItems)
                    reloadDataRelay.accept(())
                    
                    // 开始压缩
                    for item in newItems {
                        self.compressItem(item) { result in
                            switch result {
                            case .success(let compressedItem):
                                var arr = imageItemsRelay.value
                                if let index = arr.firstIndex(where: { $0.identifier == compressedItem.identifier }) {
                                    arr[index] = compressedItem
                                    imageItemsRelay.accept(arr)
                                    updateImageDriver.accept([IndexPath(row: index, section: 0)])
                                }
                            case .failure(let error):
                                print("compress image failed:\(error)")
                            }
                        }
                    }
                }
            })
            .disposed(by: disposeBag)
        
        return Output(
            imageItems: imageItemsRelay.asDriver(),
            showImagePicker: input.selectImageRelay.asDriver(onErrorJustReturn: ()),
            reloadData: reloadDataRelay.asDriver(),
            reloadIndexPaths: updateImageDriver.asDriver()
        )
    }
    
    private func loadOriginalImage(_ asset: PHAsset, completion: @escaping (ImageItem) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let imageManager = PHImageManager.default()
        let fm = FileManager.default
        
        DispatchQueue.global().async {
            print("start get original image:\(asset.localIdentifier)")
            
            let resource = PHAssetResource.assetResources(for: asset).first
            let fileSize = resource?.value(forKey: "fileSize") as? Int ?? 0
            
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { (data: Data?, uti: String?, _ , _) in
                guard let data = data else {
                    return
                }
                
                do {
                    let item = ImageItem(asset: asset, imageFileSize: fileSize)
                    let orignalImageUrl = item.orignalImageUrl
                    if fm.fileExists(atPath: orignalImageUrl.path) {
                        try fm.removeItem(at: orignalImageUrl)
                    }
                    
                    fm.createFile(atPath: orignalImageUrl.path, contents: nil)
                    try data.write(to: orignalImageUrl)

                    print("get orignal image success:\(asset.localIdentifier)")
                    completion(item)
                } catch {
                    print("get orignal image failed:\(error)")
                    return
                }
            }
        }
    }
    
    private func compressItem(_ item: ImageItem, completion: @escaping (Result<ImageItem, Error>) -> Void) {
        let compressedImageURL = item.compressedImageURL
        let fm = FileManager.default
        DispatchQueue.global().async {
            do {
                let orignalData: Data = try Data(contentsOf: item.orignalImageUrl)
                
                if fm.fileExists(atPath: compressedImageURL.path) {
                    try fm.removeItem(at: compressedImageURL)
                }
                fm.createFile(atPath: compressedImageURL.path, contents: nil)
                let startDate = Date()
                
                var compressedData: Data?
                print("compress image:\(item.imageType.rawValue)")
                compressedData = UIImage.compressImageData(orignalData)
                
                try compressedData?.write(to: compressedImageURL)
                var updateItem = item
                updateItem.compressedTime = Date().timeIntervalSince(startDate)
                completion(.success(updateItem))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
