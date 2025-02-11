//
//  STAlbumVM.swift
//  STAlbumModule
//
//  Created by stephen Li on 2025/2/11.
//

import Foundation
import STRxInOutPutProtocol
import RxSwift
import RxCocoa
import Photos

class STAlbumVM: STViewModelProtocol {
    var disposeBag = RxSwift.DisposeBag()
    
    private let selectedAlbumTypeRelay = BehaviorRelay<AlbumType>(value: .recentlyAdded)
    
    private var selectedCollection: PHAssetCollection?
    
    init() {
        // 在初始化时获取默认相册
        STAlbumService.shared.fetchDefaultAlbum()
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] collection in
                self?.selectedCollection = collection
            })
            .disposed(by: disposeBag)
    }
    
    struct Input {
        let viewWillAppear: Observable<Void>
        let itemSelected: Observable<IndexPath>
        let loadMore: Observable<Void>
        let albumTypeSelected: Observable<AlbumType>
        let albumCollectionSelected: Observable<PHAssetCollection>
    }
    
    struct OutPut {
        let albums: Observable<[AlbumModel]>
        let selectedAlbum: Observable<AlbumModel>
        let error: Observable<Error>
        let currentAlbumType: Observable<AlbumType>
    }
    
    private let albumsRelay = BehaviorRelay<[AlbumModel]>(value: [])
    private let errorRelay = PublishRelay<Error>()
    private var currentPage = 0
    private let pageSize = 20
    private var isLoading = false
    private var hasMoreData = true
    
    func transformInput(_ input: Input) -> OutPut {
        // 处理相册类型选择
        input.albumTypeSelected
            .do(onNext: { [weak self] _ in
                self?.currentPage = 0
                self?.hasMoreData = true
            })
            .bind(to: selectedAlbumTypeRelay)
            .disposed(by: disposeBag)
        
        // 处理相册选择
        input.albumCollectionSelected
            .do(onNext: { [weak self] collection in
                self?.selectedCollection = collection
                self?.currentPage = 0
                self?.hasMoreData = true
            })
            .flatMapLatest { [weak self] collection -> Observable<[AlbumModel]> in
                guard let self = self else { return .empty() }
                return self.fetchPhotosFromCollection(collection)
                    .catch { error in
                        self.errorRelay.accept(error)
                        return .just([])
                    }
            }
            .bind(to: albumsRelay)
            .disposed(by: disposeBag)
        
        // 修改 viewWillAppear 处理，加载默认相册
        input.viewWillAppear
            .flatMapLatest { [weak self] _ -> Observable<[AlbumModel]> in
                guard let self = self, let collection = self.selectedCollection else { return .empty() }
                return STAlbumService.shared.fetchPhotos(from: collection, page: self.currentPage, pageSize: self.pageSize)
                    .map { photos in
                        return photos.map { photo in
                            return AlbumModel(
                                id: photo.asset.localIdentifier,
                                name: "",
                                count: 0,
                                thumbnail: photo.thumbnail
                            )
                        }
                    }
                    .catch { error in
                        self.errorRelay.accept(error)
                        return .just([])
                    }
            }
            .bind(to: albumsRelay)
            .disposed(by: disposeBag)
        
        // 修改加载更多的处理
        input.loadMore
            .filter { [weak self] _ in
                guard let self = self else { return false }
                return !self.isLoading && self.hasMoreData
            }
            .flatMapLatest { [weak self] _ -> Observable<[AlbumModel]> in
                guard let self = self, let collection = self.selectedCollection else { return .empty() }
                self.currentPage += 1
                return self.fetchPhotosFromCollection(collection)
                    .catch { error in
                        self.errorRelay.accept(error)
                        return .just([])
                    }
            }
            .withLatestFrom(albumsRelay) { newAlbums, existingAlbums in
                return existingAlbums + newAlbums
            }
            .bind(to: albumsRelay)
            .disposed(by: disposeBag)
        
        // 处理选择
        let selectedAlbum = input.itemSelected
            .withLatestFrom(albumsRelay) { indexPath, albums in
                return albums[indexPath.row]
            }
        
        return OutPut(
            albums: albumsRelay.asObservable(),
            selectedAlbum: selectedAlbum,
            error: errorRelay.asObservable(),
            currentAlbumType: selectedAlbumTypeRelay.asObservable()
        )
    }
    
    private func fetchAlbums(type: AlbumType) -> Observable<[AlbumModel]> {
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onCompleted()
                return Disposables.create()
            }
            
            self.isLoading = true
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let result: PHFetchResult<PHAssetCollection>
            
            switch type {
            case .recentlyAdded:
                // 获取最近添加的照片
                let smartAlbums = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: .smartAlbumRecentlyAdded,
                    options: nil
                )
                result = smartAlbums
                
            case .userAlbums:
                // 获取用户创建的相册
                result = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .any,
                    options: nil
                )
            }
            
            let start = self.currentPage * self.pageSize
            let end = min(start + self.pageSize, result.count)
            let totalCount = result.count
            
            if start >= totalCount {
                self.hasMoreData = false
                observer.onNext([])
                observer.onCompleted()
                self.isLoading = false
                return Disposables.create()
            }
            
            var albums: [AlbumModel] = []
            
            for index in start..<end {
                guard let collection = result[index] as? PHAssetCollection else { continue }
                
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                guard assets.count > 0 else { continue }
                
                // 获取封面图
                let asset = assets.firstObject
                let manager = PHImageManager.default()
                let targetSize = CGSize(width: 200, height: 200)
                
                manager.requestImage(
                    for: asset!,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: nil
                ) { image, _ in
                    let album = AlbumModel(
                        id: collection.localIdentifier,
                        name: collection.localizedTitle ?? "",
                        count: assets.count,
                        thumbnail: image
                    )
                    albums.append(album)
                    
                    if albums.count == end - start {
                        observer.onNext(albums)
                        observer.onCompleted()
                        self.isLoading = false
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    // 新增：从指定相册获取照片
    private func fetchPhotosFromCollection(_ collection: PHAssetCollection) -> Observable<[AlbumModel]> {
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onCompleted()
                return Disposables.create()
            }
            
            self.isLoading = true
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            let start = self.currentPage * self.pageSize
            let end = min(start + self.pageSize, assets.count)
            
            if start >= assets.count {
                self.hasMoreData = false
                observer.onNext([])
                observer.onCompleted()
                self.isLoading = false
                return Disposables.create()
            }
            
            var photos: [AlbumModel] = []
            let manager = PHImageManager.default()
            let targetSize = CGSize(width: 200, height: 200)
            
            for index in start..<end {
                let asset = assets[index]
                manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: nil
                ) { image, _ in
                    let photo = AlbumModel(
                        id: asset.localIdentifier,
                        name: "",  // 照片不需要名称
                        count: 0,  // 照片不需要数量
                        thumbnail: image
                    )
                    photos.append(photo)
                    
                    if photos.count == end - start {
                        observer.onNext(photos)
                        observer.onCompleted()
                        self.isLoading = false
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    // 添加获取相簿列表的方法
    func fetchAlbumList() -> Observable<[PHAssetCollection]> {
        return Observable.create { observer in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            // 获取智能相册（包含"最近添加"等系统相册）
            let smartAlbums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .any,
                options: nil
            )
            
            // 获取用户创建的相册
            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .any,
                options: nil
            )
            
            var albums: [PHAssetCollection] = []
            
            // 添加智能相册
            smartAlbums.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                // 只保留我们想要显示的相册类型
                let includedSubtypes: [PHAssetCollectionSubtype] = [
                    .smartAlbumUserLibrary,  // 所有照片
                    .smartAlbumFavorites,    // 收藏
                    .smartAlbumRecentlyAdded // 最近添加
                ]
                
                if assets.count > 0 && includedSubtypes.contains(collection.assetCollectionSubtype) {
                    albums.append(collection)
                }
            }
            
            // 添加用户创建的相册
            userAlbums.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                if assets.count > 0 {
                    albums.append(collection)
                }
            }
            
            observer.onNext(albums)
            observer.onCompleted()
            
            return Disposables.create()
        }
    }
}

struct AlbumModel {
    let id: String
    let name: String
    let count: Int
    let thumbnail: UIImage?
}

// 新增相册类型枚举
enum AlbumType {
    case recentlyAdded  // 最近添加
    case userAlbums     // 用户相册
    
    var title: String {
        switch self {
        case .recentlyAdded:
            return "最近添加"
        case .userAlbums:
            return "相册"
        }
    }
}
