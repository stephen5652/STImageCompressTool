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

class ViewController: UIViewController, UITableViewDelegate {
    
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
    
    private var dataSource: [ImageItem] = []
    
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
            reloadDataRelay: selectedAssetsRelay
        )
        
        // 获取输出
        let output = viewModel.transform(input)
        
        // 数据源更新 - 确保在主线程
        output.imageItems
            .drive(onNext: { [weak self] items in
                self?.dataSource = items
            })
            .disposed(by: disposeBag)
        
        // 设置 TableView 数据源
        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)
        tableView.rx.setDataSource(self)
            .disposed(by: disposeBag)
        
        // 处理选择图片
        output.showImagePicker
            .drive(onNext: { [weak self] in
                self?.showImagePicker()
            })
            .disposed(by: disposeBag)
        
        // 全局刷新 - 添加/清空图片时
        output.reloadData
            .drive(onNext: { [weak self] in
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)
        
        // 局部刷新 - 压缩完成时
        output.reloadIndexPaths
            .filter { !$0.isEmpty }
            .drive(onNext: { [weak self] indexPaths in
                self?.tableView.reloadRows(at: indexPaths, with: .none)
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

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ImageCompressCell.identifier, for: indexPath) as! ImageCompressCell
        print("load cell:\(indexPath.row)")
        
        let item = dataSource[indexPath.row]
        let cellViewModel = ImageCompressCellViewModel(item: item)
        cell.configure(with: cellViewModel)
        
        return cell
    }
}
