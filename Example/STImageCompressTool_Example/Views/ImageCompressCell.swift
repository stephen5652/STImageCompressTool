import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RxRelay

class ImageCompressCell: UITableViewCell {
    static let identifier = "ImageCompressCell"
    
    // MARK: - UI Components
    private lazy var originalImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray6
        return imageView
    }()
    
    private lazy var compressedImageView: UIImageView = {
        let imageView = UIImageView()
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
        contentView.addSubview(originalImageView)
        contentView.addSubview(compressedImageView)
        contentView.addSubview(infoLabel)
        
        // 设置固定的 cell 高度
        contentView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        
        originalImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(10)
            make.width.height.equalTo(120)
        }
        
        compressedImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(10)
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
        
        let input = ImageCompressCellViewModel.Input()
        
        let output = viewModel.transform(input)
        
        // 绑定输出
        output.originalImage
            .drive(originalImageView.rx.image)
            .disposed(by: disposeBag)
        
        output.compressedImage
            .drive(compressedImageView.rx.image)
            .disposed(by: disposeBag)
        
        output.infoText
            .drive(infoLabel.rx.text)
            .disposed(by: disposeBag)
    }
    
}
