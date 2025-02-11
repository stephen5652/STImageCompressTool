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
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 2
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing
        
        // 计算每行显示3个图片的大小
        let width = (UIScreen.main.bounds.width - spacing * 4) / 3
        layout.itemSize = CGSize(width: width, height: width)
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .white
        cv.register(AlbumCell.self, forCellWithReuseIdentifier: "AlbumCell")
        return cv
    }()
    
    private let viewWillAppearSubject = PublishSubject<Void>()
    private let selectedIndexSubject = PublishSubject<IndexPath>()
    private let loadMoreSubject = PublishSubject<Void>()
    private let albumTypeSelectedSubject = PublishSubject<AlbumType>()
    private let albumCollectionSelectedSubject = PublishSubject<PHAssetCollection>()
    
    private func setupCollectionViewLayout() {
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let spacing: CGFloat = 2
            layout.minimumLineSpacing = spacing
            layout.minimumInteritemSpacing = spacing
            
            // 计算每行显示3个图片的大小
            let width = (UIScreen.main.bounds.width - spacing * 4) / 3
            layout.itemSize = CGSize(width: width, height: width)
            layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "最近添加"
        setupNavigationBar()
        setupCollectionViewLayout()
        checkPhotoLibraryPermission()
        setUpUI()
        bindData()
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
                        self?.viewWillAppearSubject.onNext(())
                    } else {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        } else if status != .authorized {
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
            title: "切换相册",
            style: .plain,
            target: self,
            action: #selector(showAlbumTypeSelector)
        )
        navigationItem.rightBarButtonItem = rightButton
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
    
    func bindData() {
        let input = STAlbumVM.Input(
            viewWillAppear: viewWillAppearSubject.asObservable(),
            itemSelected: selectedIndexSubject.asObservable(),
            loadMore: loadMoreSubject.asObservable(),
            albumTypeSelected: albumTypeSelectedSubject.asObservable(),
            albumCollectionSelected: albumCollectionSelectedSubject.asObservable()
        )
        
        let output = vm.transformInput(input)
        
        // 更新 cell 配置
        output.albums
            .bind(to: collectionView.rx.items(cellIdentifier: "AlbumCell", cellType: AlbumCell.self)) { index, model, cell in
                cell.imageView.image = model.thumbnail
            }
            .disposed(by: vm.disposeBag)
        
        output.selectedAlbum
            .subscribe(onNext: { [weak self] album in
                // TODO: 处理相册选择，跳转到相册详情页
                print("Selected album: \(album.name)")
            })
            .disposed(by: vm.disposeBag)
        
        collectionView.rx.itemSelected
            .bind(to: selectedIndexSubject)
            .disposed(by: vm.disposeBag)
        
        // 监听滚动到底部事件，触发加载更多
        collectionView.rx.contentOffset
            .map { [weak self] offset in
                guard let self = self else { return false }
                let contentHeight = self.collectionView.contentSize.height
                let scrollViewHeight = self.collectionView.bounds.height
                let threshold: CGFloat = 100
                return offset.y + scrollViewHeight + threshold >= contentHeight
            }
            .distinctUntilChanged()
            .filter { $0 }
            .map { _ in () }
            .bind(to: loadMoreSubject)
            .disposed(by: vm.disposeBag)
        
        output.error
            .subscribe(onNext: { [weak self] error in
                // TODO: 显示错误提示
                print("Error: \(error)")
            })
            .disposed(by: vm.disposeBag)
        
        // 监听相册类型变化，更新标题
        output.currentAlbumType
            .map { $0.title }
            .bind(to: navigationItem.rx.title)
            .disposed(by: vm.disposeBag)
    }
}

extension STAlbumVC: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
