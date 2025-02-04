//
//  ViewController.swift
//  STImageCompressTool_Example
//
//  Created by stephenchen on 2025/01/23.
//

import UIKit
import STImageCompressTool
import PhotosUI
import RxSwift
import RxCocoa
import SnapKit
import Photos

class ViewController: UIViewController {
    
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.register(ImageCompressCell.self, forCellReuseIdentifier: ImageCompressCell.identifier)
        table.separatorStyle = .none
        table.backgroundColor = .systemGroupedBackground
        return table
    }()
    
    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("添加图片", for: .normal)
        return button
    }()
    
    private lazy var clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("清空", for: .normal)
        return button
    }()

    private let viewModel: ImageCompressViewModelType = ImageCompressViewModel()
    private let disposeBag = DisposeBag()
    
    // 移除不需要的 Relay
    private let selectImageRelay = PublishRelay<Void>()
    private let selectedAssetsRelay = PublishRelay<([PHAsset],Bool)>()
    private let itemUpdatedRelay = PublishRelay<[ImageItem]>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "图片压缩工具"
        
        view.addSubview(tableView)
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
        }
        
        let hStack = UIStackView(arrangedSubviews: [clearButton, addButton])
        hStack.axis = .horizontal
        view.addSubview(hStack)
        
        hStack.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(44)
        }
        
        clearButton.snp.makeConstraints { make in
            make.width.equalTo(addButton)
        }
    }
    
    private func bindViewModel() {
        // 绑定按钮事件到 Relay
        addButton.rx.tap
            .bind(to: selectImageRelay)
            .disposed(by: disposeBag)
        
        clearButton.rx.tap
            .bind(onNext: { [weak self] in
                self?.selectedAssetsRelay.accept(([], true))
            })
            .disposed(by: disposeBag)
        
        // 构建输入
        let input = ImageCompressViewModel.Input(
            selectImageRelay: selectImageRelay,
            updateImageRelay: itemUpdatedRelay,
            reloadDataRelay: selectedAssetsRelay
        )
        
        // 获取输出
        let output = viewModel.transform(input)
        
        // 修改列表数据绑定
        output.imageItems.bind(to: tableView.rx.items(cellIdentifier: ImageCompressCell.identifier, cellType: ImageCompressCell.self)) { [weak self] (index, item, cell) in
            // 创建 ViewModel 时传入回调
            let cellViewModel = ImageCompressCellViewModel(item: item) { [weak self] updatedItem in
                self?.itemUpdatedRelay.accept([updatedItem])
            }
            cell.configure(with: cellViewModel)
        }
        .disposed(by: disposeBag)
        
        // 处理选择图片
        output.showImagePicker
            .drive(onNext: { [weak self] in
                self?.showImagePicker()
            })
            .disposed(by: disposeBag)
        
        output.reloadData.drive(onNext: { [weak self] in
            self?.tableView.reloadData()
        })
        .disposed(by: disposeBag)
        
        output.reloadIndexPaths.drive(onNext: { [weak self] (indexPaths) in
            if let weakSelf = self {
                weakSelf.tableView.reloadRows(at: indexPaths, with: .none)
            }
        })
        .disposed(by: disposeBag)
    }
    
    private func showImagePicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0 // 0 表示不限制选择数量
        config.filter = .images
        config.preferredAssetRepresentationMode = .current // 使用当前版本的资源
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        // 获取所有选中图片的 identifier
        let identifiers = results.compactMap { $0.assetIdentifier }
        guard !identifiers.isEmpty else { return }
        
        // 使用 identifier 获取 PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var selectedAssets: [PHAsset] = []
        
        fetchResult.enumerateObjects { (asset, _, _) in
            selectedAssets.append(asset)
        }
        
        if !selectedAssets.isEmpty {
            print("📸 Selected assets count: \(selectedAssets.count)")
            selectedAssetsRelay.accept((selectedAssets, false))
        }
    }
}
