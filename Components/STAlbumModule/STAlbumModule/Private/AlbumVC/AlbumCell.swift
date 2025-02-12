import UIKit
import SnapKit
import RxSwift
import Photos

class AlbumCell: UICollectionViewCell {
    private var disposeBag = DisposeBag()
    private var currentAsset: PHAsset?
    
    // Image view for the photo
    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()
    
    // Label for the asset identifier
    let identifierLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10)
        label.textColor = .white
        label.numberOfLines = 3
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Add imageView
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Add identifier label at the bottom with increased height for 3 lines
        contentView.addSubview(identifierLabel)
        identifierLabel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(40)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        identifierLabel.text = nil
        disposeBag = DisposeBag()
        currentAsset = nil
    }
    
    func configure(with model: PhotoInfo) {
        // Set the identifier
        identifierLabel.text = model.asset.localIdentifier
        
        // Set the thumbnail if available
        if let thumbnail = model.thumbnail {
            imageView.image = thumbnail
            return
        }
        
        currentAsset = model.asset
        
        // Calculate thumbnail size
        let spacing: CGFloat = 1
        let itemWidth = (UIScreen.main.bounds.width - spacing * 5) / 4
        let targetSize = CGSize(width: itemWidth, height: itemWidth)
        
        // Load thumbnail
        STAlbumService.shared.loadThumbnail(for: model.asset, targetSize: targetSize)
            .subscribe(onNext: { [weak self] image in
                // Ensure cell hasn't been reused
                guard let self = self, self.currentAsset == model.asset else { return }
                self.imageView.image = image
            })
            .disposed(by: disposeBag)
    }
} 