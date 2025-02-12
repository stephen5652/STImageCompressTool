import Foundation
import Photos
import RxSwift
import RxCocoa
import STAlbumModule

class STAlbumService {
    static let shared = STAlbumService()
    private init() {}
    
    /// 获取所有相册列表
    func fetchAlbumList() -> Observable<[AlbumInfo]> {
        return Observable.create { observer in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            // 获取智能相册
            let smartAlbums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .any,
                options: nil
            )
            
            // 获取用户相册
            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .any,
                options: nil
            )
            
            var albums: [AlbumInfo] = []
            let group = DispatchGroup()
            
            // 处理智能相册
            smartAlbums.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                if assets.count > 0 {
                    group.enter()
                    self.requestImage(
                        for: assets.firstObject!,
                        targetSize: CGSize(width: 300, height: 300)
                    ) { thumbnail in
                        let info = AlbumInfo(
                            collection: collection,
                            name: collection.localizedTitle ?? "",
                            count: assets.count,
                            identifier: collection.localIdentifier,
                            createDate: collection.startDate ?? Date(),
                            thumbnail: thumbnail
                        )
                        albums.append(info)
                        group.leave()
                    }
                }
            }
            
            // 处理用户相册
            userAlbums.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                if assets.count > 0 {
                    group.enter()
                    self.requestImage(
                        for: assets.firstObject!,
                        targetSize: CGSize(width: 300, height: 300)
                    ) { thumbnail in
                        let info = AlbumInfo(
                            collection: collection,
                            name: collection.localizedTitle ?? "",
                            count: assets.count,
                            identifier: collection.localIdentifier,
                            createDate: collection.startDate ?? Date(),
                            thumbnail: thumbnail
                        )
                        albums.append(info)
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                observer.onNext(albums)
                observer.onCompleted()
            }
            
            return Disposables.create()
        }
    }
    
    /// 从指定相册获取照片
    func fetchPhotos(from collection: PHAssetCollection, page: Int, pageSize: Int) -> Observable<[PhotoInfo]> {
        return Observable.create { observer in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            let start = page * pageSize
            let end = min(start + pageSize, assets.count)
            
            if start >= assets.count {
                observer.onNext([])
                observer.onCompleted()
                return Disposables.create()
            }
            
            // 只创建 PhotoInfo 对象，不加载图片
            var photos: [PhotoInfo] = []
            for i in start..<end {
                let asset = assets[i]
                let photo = PhotoInfo(asset: asset, thumbnail: nil)
                photos.append(photo)
            }
            
            observer.onNext(photos)
            observer.onCompleted()
            
            return Disposables.create()
        }
    }
    
    /// 获取默认相册（最近添加）
    func fetchDefaultAlbum() -> Observable<PHAssetCollection?> {
        return Observable.create { observer in
            let smartAlbums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumRecentlyAdded,
                options: nil
            )
            observer.onNext(smartAlbums.firstObject)
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    /// 检查相册权限
    func checkPhotoLibraryPermission() -> Observable<Bool> {
        return Observable.create { observer in
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized:
                observer.onNext(true)
                observer.onCompleted()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { status in
                    DispatchQueue.main.async {
                        observer.onNext(status == .authorized)
                        observer.onCompleted()
                    }
                }
            default:
                if #available(iOS 14, *) {
                    observer.onNext(status == .limited)
                } else {
                    observer.onNext(false)
                }
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }
    
    /// 统一的图片请求方法
    private func requestImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.deliveryMode = .fastFormat
        option.isNetworkAccessAllowed = true
        option.resizeMode = .exact
        option.isSynchronous = false
        
        let scale = UIScreen.main.scale
        let scaledSize = CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )
        
        manager.requestImage(
            for: asset,
            targetSize: scaledSize,
            contentMode: .aspectFill,
            options: option
        ) { image, info in
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                return
            }
            completion(image)
        }
    }
    
    /// 为单个 asset 加载缩略图
    func loadThumbnail(for asset: PHAsset, targetSize: CGSize) -> Observable<UIImage?> {
        return Observable.create { observer in
            let manager = PHImageManager.default()
            var highQualityRequestID: PHImageRequestID?
            
            // 先加载缩略图的选项
            let thumbnailOption = PHImageRequestOptions()
            thumbnailOption.deliveryMode = .fastFormat
            thumbnailOption.isNetworkAccessAllowed = true
            thumbnailOption.resizeMode = .fast
            thumbnailOption.isSynchronous = false
            
            // 高清图的选项
            let highQualityOption = PHImageRequestOptions()
            highQualityOption.deliveryMode = .highQualityFormat
            highQualityOption.isNetworkAccessAllowed = true
            highQualityOption.resizeMode = .exact
            highQualityOption.isSynchronous = false
            
            let scale = UIScreen.main.scale
            let scaledSize = CGSize(
                width: targetSize.width * scale,
                height: targetSize.height * scale
            )
            
            // 先请求缩略图
            let thumbnailRequestID = manager.requestImage(
                for: asset,
                targetSize: scaledSize,
                contentMode: .aspectFill,
                options: thumbnailOption
            ) { image, info in
                if let image = image {
                    observer.onNext(image)
                }
                
                // 再请求高清图
                highQualityRequestID = manager.requestImage(
                    for: asset,
                    targetSize: scaledSize,
                    contentMode: .aspectFill,
                    options: highQualityOption
                ) { image, info in
                    if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                        return
                    }
                    if let image = image {
                        observer.onNext(image)
                    }
                    observer.onCompleted()
                }
            }
            
            // 返回清理函数
            return Disposables.create {
                manager.cancelImageRequest(thumbnailRequestID)
                if let highQualityRequestID = highQualityRequestID {
                    manager.cancelImageRequest(highQualityRequestID)
                }
            }
        }
    }
} 
