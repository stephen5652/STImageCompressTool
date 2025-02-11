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
                    self.fetchThumbnail(for: assets.firstObject!) { thumbnail in
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
                    self.fetchThumbnail(for: assets.firstObject!) { thumbnail in
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
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            let start = page * pageSize
            let end = min(start + pageSize, assets.count)
            
            if start >= assets.count {
                observer.onNext([])
                observer.onCompleted()
                return Disposables.create()
            }
            
            var photos: [PhotoInfo] = []
            let group = DispatchGroup()
            
            for index in start..<end {
                let asset = assets[index]
                group.enter()
                self.fetchThumbnail(for: asset) { thumbnail in
                    let photo = PhotoInfo(
                        asset: asset,
                        thumbnail: thumbnail
                    )
                    photos.append(photo)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                observer.onNext(photos)
                observer.onCompleted()
            }
            
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
    
    private func fetchThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.deliveryMode = .fastFormat
        option.isSynchronous = false
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: option
        ) { image, _ in
            completion(image)
        }
    }
} 
