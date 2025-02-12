//
//  STPhotoPreviewVC.swift
//  STAlbumModule
//
//  Created by stephen Li on 2025/2/12.
//

import UIKit
import STAllBase
import Photos
import RxSwift
import RxCocoa
import SnapKit

class STPhotoPreviewVC: STBaseVCMvvm {
    private let disposeBag = DisposeBag()
    var vm = STPhotoPreviewVM()
    
    private var assetCollection: PHAssetCollection
    private var currentIndex: IndexPath
    
    // 保存原来的导航栏样式
    private var originalBackgroundImage: UIImage?
    private var originalShadowImage: UIImage?
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.isPagingEnabled = true  // 启用分页滑动
        cv.showsHorizontalScrollIndicator = false
        cv.register(PreviewCell.self, forCellWithReuseIdentifier: "PreviewCell")
        return cv
    }()
    
    init(collection: PHAssetCollection, currentIndex: IndexPath = IndexPath(row: 0, section: 0)) {
        self.assetCollection = collection
        self.currentIndex = currentIndex
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 保存原来的导航栏样式
        if let navigationBar = navigationController?.navigationBar {
            originalBackgroundImage = navigationBar.backgroundImage(for: .default)
            originalShadowImage = navigationBar.shadowImage
        }
        
        // 设置导航栏样式
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        
        setUpUI()
        bindData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 设置导航栏透明
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 恢复导航栏原来的样式
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.setBackgroundImage(originalBackgroundImage, for: .default)
            navigationBar.shadowImage = originalShadowImage
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = view.bounds.size
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            collectionView.collectionViewLayout.invalidateLayout()
            
            // 在布局更新后再次确保偏移量正确
            let offset = CGPoint(
                x: CGFloat(currentIndex.row) * view.bounds.width,
                y: 0
            )
            collectionView.setContentOffset(offset, animated: false)
        }
    }
    
    private func setUpUI() {
        view.backgroundColor = .black
        
        // 调整 CollectionView 布局
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 设置 CollectionView 属性
        collectionView.backgroundColor = .black
        collectionView.contentInsetAdjustmentBehavior = .never // 防止自动调整内容区域
    }
    
    func bindData() {
        let input = STPhotoPreviewVM.Input(
            assetCollection: assetCollection,
            currentIndex: currentIndex
        )
        
        let output = vm.transformInput(input)
        
        // 绑定图片数据到 collectionView
        output.photos
            .take(1)
            .observe(on: MainScheduler.instance)
            .do(onNext: { [weak self] photos in
                guard let self = self,
                      !photos.isEmpty,
                      self.currentIndex.row < photos.count else { return }
                
                // 强制布局
                self.view.layoutIfNeeded()
                
                // 设置偏移量
                let offset = CGPoint(
                    x: CGFloat(self.currentIndex.row) * self.view.bounds.width,
                    y: 0
                )
                self.collectionView.setContentOffset(offset, animated: false)
                
                // 更新标题
                self.title = "\(self.currentIndex.row + 1)/\(photos.count)"
            })
            .bind(to: collectionView.rx.items(cellIdentifier: "PreviewCell", cellType: PreviewCell.self)) { [weak self] index, asset, cell in
                cell.configure(with: asset)
            }
            .disposed(by: disposeBag)
        
        // 监听滚动，更新标题显示当前位置
        collectionView.rx.willEndDragging
            .map { [weak self] _, targetContentOffset in
                guard let self = self else { return 0 }
                let page = Int(targetContentOffset.pointee.x / self.view.bounds.width)
                return page + 1  // 从1开始计数
            }
            .withLatestFrom(output.photos) { (page: Int, photos: [PHAsset]) in
                return "\(page)/\(photos.count)"
            }
            .bind(to: rx.title)
            .disposed(by: disposeBag)
    }
}

// 预览Cell
class PreviewCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        return iv
    }()
    
    private var currentAsset: PHAsset?
    private var requestID: PHImageRequestID?
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func configure(with asset: PHAsset) {
        currentAsset = asset
        
        // 请求高清图片
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false  // 确保异步加载
        options.resizeMode = .exact    // 精确的大小调整
        
        // 计算目标大小
        let scale = UIScreen.main.scale
        let targetSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, info in
            guard let self = self,
                  self.currentAsset == asset,
                  let image = image else { return }
            
            self.imageView.image = image
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        currentAsset = nil
        requestID = nil
    }
}
