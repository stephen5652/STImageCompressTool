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
    
    private let viewModel: ImageCompressViewModelType = ImageCompressViewModel()
    private let disposeBag = DisposeBag()
    
    // 添加所有输入信号
    private let selectImageRelay = PublishRelay<Void>()
    private let compressImageRelay = PublishRelay<Int>()
    private let selectedImageRelay = PublishRelay<[PHAsset]>()
    
    private var items: [ImageItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "图片压缩工具"
        
        // 配置 TableView
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
        
        view.addSubview(tableView)
        view.addSubview(addButton)
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(addButton.snp.top)
        }
        
        addButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(44)
        }
    }
    
    private func bindViewModel() {
        // 绑定按钮事件到 Relay
        addButton.rx.tap
            .do(onNext: { _ in
                print("👆 Add button tapped")
            })
            .bind(to: selectImageRelay)
            .disposed(by: disposeBag)
        
        // 构建输入
        let input = ImageCompressViewModel.Input(
            selectImageRelay: selectImageRelay,
            compressImageRelay: compressImageRelay,
            selectedImageRelay: selectedImageRelay
        )
        
        // 获取输出
        let output = viewModel.transform(input)
        
        // 绑定列表数据
        output.imageItems
            .do(onNext: { items in
                print("📱 Received items count: \(items.count)")
            })
            .drive(onNext: { [weak self] items in
                guard let self = self else {
                    print("❌ Self is nil")
                    return
                }
                
                print("📱 Updating UI with items count: \(items.count)")
                // 直接更新 TableView
                self.tableView.reloadData()
                
                // 设置数据源
                self.items = items
            })
            .disposed(by: disposeBag)
        
        // 设置 TableView 数据源
        tableView.rx.setDelegate(self).disposed(by: disposeBag)
        tableView.rx.setDataSource(self).disposed(by: disposeBag)
        
        // 处理选择图片
        output.showImagePicker
            .do(onNext: { _ in
                print("🖼 Show picker triggered")
            })
            .drive(onNext: { [weak self] in
                self?.showImagePicker()
            })
            .disposed(by: disposeBag)
    }
    
    private func showImagePicker() {
        // 只请求读取权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    // 有权限，显示 PHPicker
                    self?.showPHPicker()
                case .denied, .restricted:
                    // 没有权限，显示提示
                    self?.showPermissionAlert()
                case .notDetermined:
                    // 未决定，重新请求
                    self?.showImagePicker()
                @unknown default:
                    self?.showPHPicker()
                }
            }
        }
    }
    
    private func showPHPicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0 // 0 表示不限制选择数量
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "需要相册权限",
            message: "请在设置中允许访问相册，以便选择和保存图片",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        print("📸 Picked \(results.count) images")
        picker.dismiss(animated: true)
        
        let group = DispatchGroup()
        var selectedAssets: [PHAsset] = []
        let lock = NSLock()
        
        for result in results {
            group.enter()
            
            if let assetId = result.assetIdentifier {
                // 直接从相册获取
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                if let asset = fetchResult.firstObject {
                    lock.lock()
                    selectedAssets.append(asset)
                    lock.unlock()
                }
                group.leave()
            } else {
                // 如果无法获取 assetId，直接使用 itemProvider 加载图片
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    defer { group.leave() }
                    
                    guard let image = object as? UIImage else {
                        print("❌ Failed to load image: \(error?.localizedDescription ?? "unknown error")")
                        return
                    }
                    
                    // 创建临时的 PHAsset（不保存到相册）
                    guard let imageData = image.jpegData(compressionQuality: 1.0) else {
                        print("❌ Failed to create image data")
                        return
                    }
                    
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    
                    do {
                        try imageData.write(to: tempURL)
                        if let asset = PHAsset.fetchAssets(withALAssetURLs: [tempURL], options: nil).firstObject {
                            lock.lock()
                            selectedAssets.append(asset)
                            lock.unlock()
                        }
                    } catch {
                        print("❌ Failed to create temp file: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            print("📸 Final assets count: \(selectedAssets.count)")
            if !selectedAssets.isEmpty {
                self?.selectedImageRelay.accept(selectedAssets)
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ImageCompressCell.identifier, for: indexPath) as! ImageCompressCell
        let item = items[indexPath.row]
        cell.configure(with: item)
        cell.compressAction = { [weak self] in
            self?.compressImageRelay.accept(indexPath.row)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200 // 预估高度
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

