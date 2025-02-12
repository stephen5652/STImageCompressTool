import UIKit
import SnapKit
import RxSwift
import Photos

class AlbumCell: UICollectionViewCell {
    private var disposeBag = DisposeBag()
    private var currentAsset: PHAsset?
    
    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()
    
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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        disposeBag = DisposeBag()
        currentAsset = nil
    }
    
    func configure(with model: PhotoInfo) {
        if let thumbnail = model.thumbnail {
            imageView.image = thumbnail
            return
        }
        
        currentAsset = model.asset
        
        // 计算缩略图尺寸
        let spacing: CGFloat = 1
        let itemWidth = (UIScreen.main.bounds.width - spacing * 5) / 4
        let targetSize = CGSize(width: itemWidth, height: itemWidth)
        
        STAlbumService.shared.loadThumbnail(for: model.asset, targetSize: targetSize)
            .subscribe(onNext: { [weak self] image in
                // 确保 cell 没有被重用
                guard let self = self, self.currentAsset == model.asset else { return }
                self.imageView.image = image
            })
            .disposed(by: disposeBag)
    }
} 