import UIKit
import SnapKit
import Photos

class ImageCompressCell: UITableViewCell {
    static let identifier = "ImageCompressCell"
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 8
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private let originalImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()
    
    private let compressedImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 12)
        return label
    }()
    
    private let compressButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("压缩", for: .normal)
        return button
    }()
    
    var compressAction: (() -> Void)?
    
    private let imageManager = PHImageManager.default()
    private var imageRequestID: PHImageRequestID?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(containerView)
        containerView.addSubview(originalImageView)
        containerView.addSubview(compressedImageView)
        containerView.addSubview(infoLabel)
        containerView.addSubview(compressButton)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }
        
        originalImageView.snp.makeConstraints { make in
            make.top.left.equalToSuperview().offset(12)
            make.width.height.equalTo(120)
        }
        
        compressedImageView.snp.makeConstraints { make in
            make.top.right.equalToSuperview().inset(12)
            make.width.height.equalTo(120)
        }
        
        infoLabel.snp.makeConstraints { make in
            make.top.equalTo(originalImageView.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(12)
        }
        
        compressButton.snp.makeConstraints { make in
            make.top.equalTo(infoLabel.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }
        
        compressButton.addTarget(self, action: #selector(compressButtonTapped), for: .touchUpInside)
    }
    
    @objc private func compressButtonTapped() {
        compressAction?()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // 取消正在进行的图片请求
        if let requestID = imageRequestID {
            imageManager.cancelImageRequest(requestID)
        }
        // 清理图片资源
        originalImageView.image = nil
        compressedImageView.image = nil
        infoLabel.text = nil
        compressAction = nil
    }
    
    // 在 Cell 被销毁时清理资源
    deinit {
        originalImageView.image = nil
        compressedImageView.image = nil
        compressAction = nil
    }
    
    func configure(with item: ImageItem) {
        // 清理旧的图片
        originalImageView.image = nil
        compressedImageView.image = nil
        
        // 设置缩略图选项
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.version = .current
        
        // 加载原图缩略图
        let targetSize = CGSize(width: 120, height: 120)
        imageRequestID = imageManager.requestImage(
            for: item.asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, info in
            guard let self = self, let image = image else { return }
            self.originalImageView.image = image
            self.updateOriginalInfo(image: image)
        }
        
        // 加载压缩后的图片
        if let compressedURL = item.compressedImageURL {
            loadImage(from: compressedURL) { [weak self] image in
                guard let self = self else { return }
                self.compressedImageView.image = self.resizeImage(image, to: CGSize(width: 120, height: 120))
                self.updateCompressedInfo(image: image, duration: item.compressionDuration)
            }
        }
        
        compressButton.isHidden = item.isCompressed
    }
    
    private func loadImage(from url: URL, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                if let image = UIImage(contentsOfFile: url.path) {
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            }
        }
    }
    
    private func updateOriginalInfo(image: UIImage) {
        let info = generateImageInfo(image: image, prefix: "原图")
        if compressedImageView.image == nil {
            infoLabel.text = info
        } else {
            let currentInfo = infoLabel.text ?? ""
            infoLabel.text = info + "\n" + currentInfo
        }
    }
    
    private func updateCompressedInfo(image: UIImage, duration: TimeInterval?) {
        let info = generateImageInfo(image: image, prefix: "压缩后", duration: duration)
        if let currentInfo = infoLabel.text {
            infoLabel.text = currentInfo + "\n" + info
        } else {
            infoLabel.text = info
        }
    }
    
    // 添加图片缩放方法
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    private func generateImageInfo(image: UIImage, prefix: String, duration: TimeInterval? = nil) -> String {
        var info = "\(prefix)尺寸: \(Int(image.size.width))x\(Int(image.size.height))"
        
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            info += "\n\(prefix)大小: \(String(format: "%.2f", Double(imageData.count) / 1024.0))KB"
        }
        
        if let duration = duration {
            info += "\t压缩耗时: \(String(format: "%.2f", duration))秒"
        }
        
        return info
    }
} 
