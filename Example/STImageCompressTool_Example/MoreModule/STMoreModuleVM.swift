//
//  STMoreModuleVM.swift
//  STImageCompressTool_Example
//
//  Created by stephen Li on 2025/2/18.
//

import STAllBase
import RxSwift
import RxCocoa
import RxDataSources
import Photos
import PhotosUI  // 添加 PhotosUI 导入

class STMoreModuleVM: NSObject, STViewModelProtocol {
    struct Input {}
    
    struct Output {
        let sections: Driver<[SectionModel<String, MoreItem>]>
    }
    
    var disposeBag = DisposeBag()
    
    // 数据源
    private let sectionsRelay = BehaviorRelay<[SectionModel<String, MoreItem>]>(value: [])
    
    // 定义数据源
    lazy var dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, MoreItem>>(
        configureCell: { _, tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = item.title
            cell.accessoryType = .disclosureIndicator
            return cell
        },
        titleForHeaderInSection: { dataSource, index in
            return dataSource.sectionModels[index].model
        }
    )
    
    override init() {
        super.init()
        setupSections()
    }
    
    private func setupSections() {
        // 消息功能区
        let messageSection = SectionModel(
            model: "消息",
            items: [
                MoreItem(title: "发送消息", type: .sendMessage)
            ]
        )
        
        // 媒体功能区
        let mediaSection = SectionModel(
            model: "媒体",
            items: [
                MoreItem(title: "相册", type: .album),
                MoreItem(title: "相册预览", type: .albumPreview)
            ]
        )
        
        sectionsRelay.accept([messageSection, mediaSection])
    }
    
    func transformInput(_ input: Input) -> Output {
        return Output(
            sections: sectionsRelay.asDriver(onErrorJustReturn: [])
        )
    }
    
    func handleItemSelected(at indexPath: IndexPath) {
        let item = sectionsRelay.value[indexPath.section].items[indexPath.row]
        
        switch item.type {
        case .sendMessage:
            openMessageVC()
        case .album:
            openPhotoLibrary()
        case .albumPreview:
            openAlbumPreview()
        }
    }
    
    private func openMessageVC() {
        let req = STRouterUrlRequest.instance { builder in
            builder.urlToOpen = STRouterDefine.kRouter_Message
        }
        
        stRouterOpenUrlRequest(req) { _ in }
    }
    
    private func openPhotoLibrary() {
        let req = STRouterUrlRequest.instance { builder in
            builder.urlToOpen = STRouterDefine.kRouter_AlbumList
        }
        
        stRouterOpenUrlRequest(req) {  (resp: STRouterUrlResponse) in
        }
    }
    
    private func openAlbumPreview() {
        let req = STRouterUrlRequest.instance { builder in
            builder.urlToOpen = STRouterDefine.kRouter_Album
        }
        
        stRouterOpenUrlRequest(req) { _ in }
    }
}

// 定义列表项模型
struct MoreItem {
    let title: String
    let type: MoreItemType
}

// 定义功能类型
enum MoreItemType {
    case sendMessage  // 发送消息
    case album       // 系统相册
    case albumPreview // 相册预览
}
