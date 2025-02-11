//
//  AlbumListVM.swift
//  STAlbumModule
//
//  Created by stephen Li on 2025/2/11.
//

import Foundation
import STAllBase
import Photos
import RxSwift
import RxCocoa
import STAlbumModule

/*
 1. 基于 RxSwift 的 InputOutPut 架构
 2. 进入页面后，使用 PhotoManager 拉取所有的 相册
 3. 在TableView中显示所有相册的信息： 相册Identifier， 相册名称， 相册创建时间， 相册中照片个数， 第一张照片的缩略图
 */

class AlbumListVM: STViewModelProtocol {
    var disposeBag = RxSwift.DisposeBag()
    
    struct Input {
        let viewWillAppear: Observable<Void>
        let itemSelected: Observable<IndexPath>
    }
    
    struct Output {
        let albums: Observable<[AlbumInfo]>
        let selectedAlbum: Observable<PHAssetCollection>
    }
    
    /// 选择图片后的回调
    var slectedCallBack: ((PHAssetCollection) -> Void)?
    
    private let albumsRelay = BehaviorRelay<[AlbumInfo]>(value: [])
    private let selectedAlbumRelay = PublishRelay<PHAssetCollection>()
    
    func transformInput(_ input: Input) -> Output {
        // 加载相册列表
        input.viewWillAppear
            .flatMapLatest { _ -> Observable<[AlbumInfo]> in
                return STAlbumService.shared.fetchAlbumList()
            }
            .bind(to: albumsRelay)
            .disposed(by: disposeBag)
        
        // 处理相册选择
        input.itemSelected
            .withLatestFrom(albumsRelay) { indexPath, albums in
                return albums[indexPath.row].collection
            }
            .do(onNext: { [weak self] collection in
                self?.slectedCallBack?(collection)
            })
            .bind(to: selectedAlbumRelay)
            .disposed(by: disposeBag)
        
        return Output(
            albums: albumsRelay.asObservable(),
            selectedAlbum: selectedAlbumRelay.asObservable()
        )
    }
    
    private func fetchAlbums() -> Observable<[AlbumInfo]> {
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
    
    private func fetchThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.deliveryMode = .fastFormat
        option.isSynchronous = false
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 80, height: 80),
            contentMode: .aspectFill,
            options: option
        ) { image, _ in
            completion(image)
        }
    }
}
