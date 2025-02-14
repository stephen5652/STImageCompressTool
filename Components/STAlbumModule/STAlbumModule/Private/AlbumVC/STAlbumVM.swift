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
    internal var disposeBag = DisposeBag()
    
    private let selectedAlbumTypeRelay = BehaviorRelay<AlbumType>(value: .recentlyAdded)
    private let selectedCollectionRelay = BehaviorRelay<PHAssetCollection?>(value: nil)
    
    var selectedCollection: PHAssetCollection?
    
    private var pageSize: Int
    
    private let photosRelay = BehaviorRelay<[PhotoInfo]>(value: [])
    private let errorRelay = PublishRelay<Error>()
    private var currentPage = 0
    private var isLoading = false
    private var hasMoreData = true
    private var isPreloading = false
    private let preloadThreshold = 0.7
    
    private let defaultAlbumLoadedRelay = PublishRelay<Void>()
    private let totalCountRelay = BehaviorRelay<Int>(value: 0)
    
    init() {
        self.pageSize = 60
    }
    
    struct Input {
        let viewWillAppear: Observable<Void>
        let itemSelected: Observable<IndexPath>
        let loadMore: Observable<Void>
        let albumCollectionSelected: Observable<PHAssetCollection>
        let loadDefaultAlbum: Observable<Void>
    }
    
    struct OutPut {
        let photos: Observable<[PhotoInfo]>
        let selectedAlbum: Observable<(collection: PHAssetCollection, indexPath: IndexPath)>
        let error: Observable<Error>
        let currentAlbumType: Observable<AlbumType>
        let defaultAlbumLoaded: Observable<Void>
        let selectedCollection: Observable<PHAssetCollection?>
        let totalCount: Observable<Int>
    }
    
    func transformInput(_ input: Input) -> OutPut {
        // 处理相册选择
        input.albumCollectionSelected
            .do(onNext: { [weak self] collection in
                self?.selectedCollection = collection
                self?.selectedCollectionRelay.accept(collection)
                self?.currentPage = 0
                self?.hasMoreData = true
                
                // 获取并更新总数
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                self?.totalCountRelay.accept(assets.count)
            })
            .flatMapLatest { [weak self] collection -> Observable<[PhotoInfo]> in
                guard let self = self else { return .empty() }
                return STAlbumService.shared.fetchPhotos(from: collection, page: self.currentPage, pageSize: self.pageSize)
                    .catch { error in
                        self.errorRelay.accept(error)
                        return .just([])
                    }
            }
            .bind(to: photosRelay)
            .disposed(by: disposeBag)
        
        // 处理加载默认相册
        input.loadDefaultAlbum
            .flatMapLatest { [weak self] _ -> Observable<PHAssetCollection?> in
                guard let self = self else { return .empty() }
                
                return Observable.create { observer in
                    let smartAlbums = PHAssetCollection.fetchAssetCollections(
                        with: .smartAlbum,
                        subtype: .any,
                        options: nil
                    )
                    
                    var firstAlbum: PHAssetCollection?
                    smartAlbums.enumerateObjects { collection, _, stop in
                        let assets = PHAsset.fetchAssets(in: collection, options: nil)
                        if assets.count > 0 {
                            firstAlbum = collection
                            stop.pointee = true
                        }
                    }
                    
                    observer.onNext(firstAlbum)
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
            .compactMap { $0 }
            .do(onNext: { [weak self] album in
                self?.selectedCollection = album
                
                // 获取并更新总数
                let assets = PHAsset.fetchAssets(in: album, options: nil)
                self?.totalCountRelay.accept(assets.count)
            })
            .flatMapLatest { [weak self] album -> Observable<(PHAssetCollection, [PhotoInfo])> in
                guard let self = self else { return .empty() }
                return STAlbumService.shared.fetchPhotos(from: album, page: self.currentPage, pageSize: self.pageSize)
                    .map { photos in
                        return (album, photos)
                    }
                    .catch { error in
                        self.errorRelay.accept(error)
                        return .empty()
                    }
            }
            .do(onNext: { [weak self] _, photos in
                self?.photosRelay.accept(photos)
                self?.defaultAlbumLoadedRelay.accept(())
            })
            .map { album, _ in album }
            .bind(to: selectedCollectionRelay)
            .disposed(by: disposeBag)
        
        // 优化加载更多的处理
        input.loadMore
            .filter { [weak self] _ in
                guard let self = self else { return false }
                return !self.isLoading && self.hasMoreData
            }
            .do(onNext: { [weak self] _ in
                self?.isLoading = true
            })
            .flatMapLatest { [weak self] _ -> Observable<[PhotoInfo]> in
                guard let self = self, let collection = self.selectedCollection else { return .empty() }
                
                let nextPage = self.currentPage + 1
                return STAlbumService.shared.fetchPhotos(from: collection, page: nextPage, pageSize: self.pageSize)
                    .do(onNext: { [weak self] photos in
                        guard let self = self else { return }
                        if !photos.isEmpty {
                            self.currentPage = nextPage
                        }
                        self.hasMoreData = !photos.isEmpty
                        self.isLoading = false
                    }, onError: { [weak self] _ in
                        self?.isLoading = false
                    })
            }
            .withLatestFrom(photosRelay) { (newPhotos: [PhotoInfo], existingPhotos: [PhotoInfo]) -> [PhotoInfo] in
                // 创建新数组而不是直接修改现有数组
                var updatedPhotos = existingPhotos
                updatedPhotos.append(contentsOf: newPhotos)
                return updatedPhotos
            }
            .bind(to: photosRelay)
            .disposed(by: disposeBag)
        
        // 处理选择
        let selectedAlbum = input.itemSelected
            .map { indexPath -> (collection: PHAssetCollection, indexPath: IndexPath)? in
                guard let collection = self.selectedCollection else { return nil }
                return (
                    collection: collection,
                    indexPath: indexPath
                )
            }
            .compactMap { $0 }
        
        return OutPut(
            photos: photosRelay.asObservable()
                .distinctUntilChanged { prev, current in
                    // 如果数组长度不同，说明有新数据
                    guard prev.count == current.count else { return false }
                    // 比较每个元素的 localIdentifier
                    return zip(prev, current).allSatisfy { $0.asset.localIdentifier == $1.asset.localIdentifier }
                },
            selectedAlbum: selectedAlbum,
            error: errorRelay.asObservable(),
            currentAlbumType: selectedAlbumTypeRelay.asObservable(),
            defaultAlbumLoaded: defaultAlbumLoadedRelay.asObservable(),
            selectedCollection: selectedCollectionRelay.asObservable(),
            totalCount: totalCountRelay.asObservable()
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
    
    // 添加更新页面大小的方法
    func updatePageSize(_ newSize: Int) {
        pageSize = newSize
        // 如果需要，可以在这里重新加载数据
        if let collection = selectedCollection {
            currentPage = 0
            hasMoreData = true
            isLoading = false  // 重置加载状态
            STAlbumService.shared.fetchPhotos(from: collection, page: currentPage, pageSize: pageSize)
                .catch { error in
                    self.errorRelay.accept(error)
                    return .just([])
                }
                .bind(to: photosRelay)
                .disposed(by: disposeBag)
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
