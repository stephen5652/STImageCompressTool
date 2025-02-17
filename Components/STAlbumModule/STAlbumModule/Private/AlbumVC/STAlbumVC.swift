//
//  STAlbumVC.swift
//  Pods
//
//  Created by stephen Li on 2025/2/11.
//

/*
 功能细节如下：
 1. 基于RXSwift 实现了 InputOutput 的代码模式
 2. 使用PhotoImangeManager 请求相册的文件列表，获取到 PHAssert
 3. 使用 collectionView 显示图片的缩略图
 4. collectionView 滑动过程中 分页加载相册中的文件缩略图
 */

import STAllBase
import RxSwift
import RxCocoa
import SnapKit
import Photos

class STAlbumVC: STBaseVCMvvm {
    var vm = STAlbumVM()
    private let disposeBag = DisposeBag()  // 使用自己的 disposeBag
    
    // 添加布局配置结构体
    private struct LayoutConfig {
        var itemsPerRow: Int = 5
        var spacing: CGFloat = 1
        
        func itemSize(in width: CGFloat) -> CGSize {
            let totalSpacing = spacing * CGFloat(itemsPerRow + 1)
            let itemWidth = (width - totalSpacing) / CGFloat(itemsPerRow)
            return CGSize(width: itemWidth, height: itemWidth)
        }
        
        func flowLayout(in width: CGFloat) -> UICollectionViewFlowLayout {
            let layout = UICollectionViewFlowLayout()
            layout.minimumLineSpacing = spacing
            layout.minimumInteritemSpacing = spacing
            layout.itemSize = itemSize(in: width)
            layout.sectionInset = UIEdgeInsets(
                top: spacing,
                left: spacing,
                bottom: spacing,
                right: spacing
            )
            return layout
        }
    }
    
    private var config = LayoutConfig()
    
    private lazy var collectionView: UICollectionView = {
        let layout = config.flowLayout(in: UIScreen.main.bounds.width)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .white
        cv.register(AlbumCell.self, forCellWithReuseIdentifier: "AlbumCell")
        return cv
    }()
    
    private let viewWillAppearSubject = PublishSubject<Void>()
    private let selectedIndexSubject = PublishSubject<IndexPath>()
    private let loadMoreSubject = PublishSubject<Void>()
    private let albumCollectionSelectedSubject = PublishSubject<PHAssetCollection>()
    private let loadDefaultAlbumSubject = PublishSubject<Void>()
    
    private func setupCollectionViewLayout() {
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let spacing: CGFloat = 1  // 减小间距
            layout.minimumLineSpacing = spacing
            layout.minimumInteritemSpacing = spacing
            
            // 计算每行显示4个图片的大小
            let itemWidth = (UIScreen.main.bounds.width - spacing * 5) / 4  // 5个间隔（两边各一个，中间3个）
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "相册"
        setupNavigationBar()
        setupCollectionViewLayout()
        setUpUI()
        bindData()
        checkPhotoLibraryPermission()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearSubject.onNext(())
    }
    
    private func setUpUI() {
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self?.loadDefaultAlbumSubject.onNext(())
                    } else {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        } else if status == .authorized {
            loadDefaultAlbumSubject.onNext(())
        } else {
            showPermissionDeniedAlert()
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "需要访问相册权限",
            message: "请在设置中允许访问相册",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func setupNavigationBar() {
        let rightButton = UIBarButtonItem(
            title: "相册列表",
            style: .plain,
            target: self,
            action: #selector(showAlbumTypeSelector)
        )
        
        let layoutButton = UIBarButtonItem(
            title: "布局",
            style: .plain,
            target: self,
            action: #selector(showLayoutOptions)
        )
        
        navigationItem.rightBarButtonItems = [rightButton, layoutButton]
    }
    
    @objc private func showAlbumTypeSelector() {
        let req = STRouterUrlRequest.instance { builder in
            builder.urlToOpen = STRouterDefine.kRouter_AlbumList
            builder.fromVC = self
        }
        
        stRouterOpenUrlRequest(req) { [weak self] (resp: STRouterUrlResponse) in
            guard let selectedMap = resp.responseObj as? [String: AlbumInfo] else {
                print("album list select no album:\(resp.responseObj)")
                return
            }
            
            guard let selectAlbum = selectedMap[STRouterDefine.kRouterPara_Album] as? AlbumInfo else {
                print("album list select not album:\(selectedMap)")
                return
            }
            
            self?.title = selectAlbum.name
            self?.albumCollectionSelectedSubject.onNext(selectAlbum.collection)
        }
    }
    
    @objc private func showLayoutOptions() {
        let alert = UIAlertController(
            title: "选择布局",
            message: nil,
            preferredStyle: .actionSheet
        )
        
        [3, 4, 5, 6, 7, 8].forEach { count in
            alert.addAction(UIAlertAction(
                title: "每行\(count)张",
                style: .default
            ) { [weak self] _ in
                self?.updateLayout(itemsPerRow: count)
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func updateLayout(itemsPerRow: Int) {
        config.itemsPerRow = itemsPerRow
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let newLayout = config.flowLayout(in: view.bounds.width)
            layout.itemSize = newLayout.itemSize
            layout.minimumLineSpacing = newLayout.minimumLineSpacing
            layout.minimumInteritemSpacing = newLayout.minimumInteritemSpacing
            layout.sectionInset = newLayout.sectionInset
            
            UIView.animate(withDuration: 0.3) {
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { _ in
            if let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                let newLayout = self.config.flowLayout(in: size.width)
                layout.itemSize = newLayout.itemSize
                layout.minimumLineSpacing = newLayout.minimumLineSpacing
                layout.minimumInteritemSpacing = newLayout.minimumInteritemSpacing
                layout.sectionInset = newLayout.sectionInset
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        }
    }
    
    func bindData() {
        let input = STAlbumVM.Input(
            viewWillAppear: viewWillAppearSubject.asObservable(),
            itemSelected: selectedIndexSubject.asObservable(),
            loadMore: loadMoreSubject.asObservable(),
            albumCollectionSelected: albumCollectionSelectedSubject.asObservable(),
            loadDefaultAlbum: loadDefaultAlbumSubject.asObservable()
        )
        
        let output = vm.transformInput(input)
        
        // 使用 self.disposeBag 替换 vm.disposeBag
        output.photos
            .observe(on: MainScheduler.instance)
            .bind(to: collectionView.rx.items(cellIdentifier: "AlbumCell", cellType: AlbumCell.self)) { [weak self] index, model, cell in
                cell.configure(with: model)
            }
            .disposed(by: disposeBag)
        
        output.selectedAlbum
            .subscribe(onNext: { [weak self] result in
                let collection = result.collection
                let indexPath = result.indexPath
                print("Selected album: \(collection.localizedTitle ?? ""), at index: \(indexPath)")
                let routerReq = STRouterUrlRequest.instance { builder in
                    builder.urlToOpen = STRouterDefine.kRouter_PhotoPreview
                    builder.parameter = [
                        STRouterDefine.kRouterPara_AlbumCollection: collection,
                        STRouterDefine.kRouterPara_CurIdndex: indexPath,
                    ]
                }
                
                stRouterOpenUrlRequest(routerReq) { _ in }
            })
            .disposed(by: disposeBag)
        
        collectionView.rx.itemSelected
            .bind(to: selectedIndexSubject)
            .disposed(by: disposeBag)
        
        collectionView.rx.willDisplayCell
            .observe(on: MainScheduler.instance)
            .map { cell, indexPath in
                return indexPath
            }
            .filter { [weak self] indexPath in
                guard let self = self,
                      let totalItems = self.collectionView.dataSource?.collectionView(self.collectionView, numberOfItemsInSection: 0)
                else { return false }
                
                let triggerIndex = Int(Double(totalItems) * 0.7)
                return indexPath.item >= triggerIndex
            }
            .debounce(.milliseconds(100), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .map { _ in () }
            .bind(to: loadMoreSubject)
            .disposed(by: disposeBag)
        
        output.error
            .subscribe(onNext: { [weak self] error in
                print("Error: \(error)")
            })
            .disposed(by: disposeBag)
        
        // 处理默认相册加载完成
        Observable.combineLatest(
            output.selectedCollection,
            output.totalCount
        )
        .compactMap { collection, totalCount -> (PHAssetCollection, Int)? in
            guard let collection = collection else { return nil }
            return (collection, totalCount)
        }
        .subscribe(onNext: { [weak self] collection, totalCount in
            self?.title = "\(collection.localizedTitle ?? "") (\(totalCount))"
        })
        .disposed(by: disposeBag)
    }
}

extension STAlbumVC: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
