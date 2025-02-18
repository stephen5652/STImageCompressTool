//
//  STViewControllerMore.swift
//  STImageCompressTool_Example
//
//  Created by stephen Li on 2025/2/18.
//

import STAllBase
import RxSwift
import RxCocoa
import RxDataSources

class STViewControllerMore: STBaseVCMvvm {
    var vm = STMoreModuleVM()
    private let disposeBag = DisposeBag()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        table.rx.setDelegate(self).disposed(by: disposeBag)
        return table
    }()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        title = "更多功能"
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func bindData() {
        let input = STMoreModuleVM.Input()
        let output = vm.transformInput(input)
        
        // 绑定数据源
        output.sections
            .drive(tableView.rx.items(dataSource: vm.dataSource))
            .disposed(by: disposeBag)
        
        // 处理点击事件
        tableView.rx.itemSelected
            .do(onNext: { [weak self] indexPath in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            })
            .bind(onNext: { [weak self] indexPath in
                self?.vm.handleItemSelected(at: indexPath)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - UITableViewDelegate
extension STViewControllerMore: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
}
