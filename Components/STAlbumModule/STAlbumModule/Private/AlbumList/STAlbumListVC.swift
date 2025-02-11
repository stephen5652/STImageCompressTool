import UIKit
import RxSwift
import RxCocoa
import Photos
import SnapKit
import STAllBase

class STAlbumListVC: STBaseVCMvvm {
    let disposeBag = DisposeBag()
    var vm = AlbumListVM()
    
    private let viewWillAppearSubject = PublishSubject<Void>()
    private let selectedIndexSubject = PublishSubject<IndexPath>()
    
    var selectCallback: ((_ album: AlbumInfo) -> Void)?
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(STAlbumListCell.self, forCellReuseIdentifier: "STAlbumListCell")
        tv.rowHeight = 64
        tv.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        return tv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "选择相册"
        setupUI()
        bindData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearSubject.onNext(())
    }
    
    private func setupUI() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func bindData() {
        let input = AlbumListVM.Input(
            viewWillAppear: viewWillAppearSubject.asObservable(),
            itemSelected: selectedIndexSubject.asObservable()
        )
        
        let output = vm.transformInput(input)
        
        // 绑定相册列表到 tableView
        output.albums
            .bind(to: tableView.rx.items(cellIdentifier: "STAlbumListCell", cellType: STAlbumListCell.self)) { _, albumInfo, cell in
                cell.configure(
                    title: albumInfo.name,
                    count: albumInfo.count,
                    identifier: albumInfo.identifier,
                    thumbnail: albumInfo.thumbnail
                )
            }
            .disposed(by: disposeBag)
        
        // 处理选择事件
        tableView.rx.itemSelected
            .withLatestFrom(output.albums) { indexPath, albums in
                return albums[indexPath.row]  // 获取 PHAssetCollection
            }
            .subscribe(onNext: { [weak self] album in
                self?.selectCallback?(album)  // 触发回调
                self?.navigationController?.popViewController(animated: true)
            })
            .disposed(by: disposeBag)
    }
}

// 相册列表 Cell
class STAlbumListCell: UITableViewCell {
    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray6
        iv.layer.cornerRadius = 4
        return iv
    }()
    
    private let titleContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gray
        return label
    }()
    
    private let identifierLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .lightGray
        label.numberOfLines = 0  // 允许多行
        return label
    }()
    
    private let labelsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8  // 增加间距
        stack.alignment = .leading
        return stack
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(coverImageView)
        contentView.addSubview(labelsStackView)
        
        // 创建标题容器
        titleContainer.addArrangedSubview(titleLabel)
        titleContainer.addArrangedSubview(countLabel)
        
        labelsStackView.addArrangedSubview(titleContainer)
        labelsStackView.addArrangedSubview(identifierLabel)
        
        coverImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(60)
        }
        
        labelsStackView.snp.makeConstraints { make in
            make.left.equalTo(coverImageView.snp.right).offset(12)
            make.right.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
        }
        
        // 设置分割线
        separatorInset = UIEdgeInsets(top: 0, left: 87, bottom: 0, right: 15)
        
        // 设置选中样式
        selectionStyle = .gray
    }
    
    func configure(title: String, count: Int, identifier: String, thumbnail: UIImage?) {
        titleLabel.text = title
        countLabel.text = "(\(count))"
        identifierLabel.text = "ID: \(identifier)"  // identifier 会自动换行
        coverImageView.image = thumbnail
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.image = nil
        titleLabel.text = nil
        countLabel.text = nil
        identifierLabel.text = nil
    }
}

// 通知名称扩展
extension Notification.Name {
    static let albumSelected = Notification.Name("albumSelected")
} 
