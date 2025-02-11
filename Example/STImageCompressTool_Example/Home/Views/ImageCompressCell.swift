import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RxRelay
import Kingfisher
import STImageCompressTool
import RxGesture

class ImageCompressCell: UITableViewCell {
    static let identifier = "ImageCompressCell"
    
    // MARK: - UI Components
    private lazy var originalTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "原图"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var compressedTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "压缩后"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var originalImageView: AnimatedImageView = {
        let imageView = AnimatedImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray6
        return imageView
    }()
    
    private lazy var compressedImageView: AnimatedImageView = {
        let imageView = AnimatedImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray6
        return imageView
    }()
    
    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .left
        return label
    }()
    
    // MARK: - Properties
    private var viewModel: ImageCompressCellViewModel?
    private var disposeBag = DisposeBag()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        originalImageView.image = nil
        compressedImageView.image = nil
        infoLabel.text = nil
        viewModel = nil
        disposeBag = DisposeBag()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        selectionStyle = .none
        contentView.addSubview(originalTitleLabel)
        contentView.addSubview(compressedTitleLabel)
        contentView.addSubview(originalImageView)
        contentView.addSubview(compressedImageView)
        contentView.addSubview(infoLabel)
        
        // 设置固定的 cell 高度
        contentView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        
        originalTitleLabel.snp.makeConstraints { make in
            make.centerX.equalTo(originalImageView)
            make.bottom.equalTo(originalImageView.snp.top).offset(-5)
        }
        
        compressedTitleLabel.snp.makeConstraints { make in
            make.centerX.equalTo(compressedImageView)
            make.bottom.equalTo(compressedImageView.snp.top).offset(-5)
        }
        
        originalImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(30)
            make.width.height.equalTo(120)
        }
        
        compressedImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(30)
            make.width.height.equalTo(120)
        }
        
        infoLabel.snp.makeConstraints { make in
            make.left.equalTo(originalImageView)
            make.right.equalTo(compressedImageView)
            make.top.equalTo(originalImageView.snp.bottom).offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
    }
    
    // MARK: - Configuration
    func configure(with viewModel: ImageCompressCellViewModel) {
        self.viewModel = viewModel
        
        let input = ImageCompressCellViewModel.Input(
            originalImageTap: originalImageView.rx.tapGesture().when(.recognized).map { _ in () },
            compressedImageTap: compressedImageView.rx.tapGesture().when(.recognized).map { _ in () }
        )
        
        let output = viewModel.transform(input)
        
        // 绑定输出
        output.originalImage
            .drive(onNext: { [weak self] (url) in
                guard let self = self, let url else { return }
//                originalImageView.kfSetImage(localPath: url.path)
            })
            .disposed(by: disposeBag)
        
        output.compressedImage
            .drive(onNext: { [weak self] (url) in
                guard let self = self, let url else { return }
                compressedImageView.kfSetImage(localPath: url.path)
            })
            .disposed(by: disposeBag)

        output.infoText
            .drive(infoLabel.rx.text)
            .disposed(by: disposeBag)
    }
    
}
