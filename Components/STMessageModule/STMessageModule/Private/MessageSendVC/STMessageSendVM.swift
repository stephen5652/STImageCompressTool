//
//  STMessageSendVM.swift
//  STMessageModule
//
//  Created by stephen Li on 2025/2/18.
//

import STAllBase
import RxSwift
import RxCocoa

class STMessageSendVM: STViewModelProtocol {
    struct Input {
        let sendMessage: Observable<String>  // 发送文本消息
        let sendImage: Observable<UIImage>   // 发送图片消息
        let selectImage: Observable<Void>    // 选择图片
        let pasteAction: Observable<Void>    // 粘贴事件
    }
    
    struct Output {
        let messages: Driver<[MessageItem]>     // 消息列表
        let showImagePicker: Driver<Void>       // 显示图片选择器
        let pasteboardContent: Driver<PasteboardContent>  // 粘贴板内容
    }
    
    // 粘贴板内容类型
    enum PasteboardContent {
        case none
        case text(String)
        case image(UIImage)
    }
    
    var disposeBag = DisposeBag()
    private let messagesRelay = BehaviorRelay<[MessageItem]>(value: [])
    
    public init() {}
    
    func transformInput(_ input: Input) -> Output {
        // 处理发送文本消息
        input.sendMessage
            .map { text -> MessageItem in
                MessageItem(
                    id: UUID().uuidString,
                    content: text,
                    type: .text,
                    isOutgoing: true,
                    timestamp: Date()
                )
            }
            .withLatestFrom(messagesRelay) { (newMessage, messages) -> [MessageItem] in
                var updatedMessages = messages
                updatedMessages.append(newMessage)
                return updatedMessages
            }
            .bind(to: messagesRelay)
            .disposed(by: disposeBag)
        
        // 处理发送图片消息
        input.sendImage
            .map { image -> MessageItem in
                MessageItem(
                    id: UUID().uuidString,
                    content: "",
                    type: .image(image),
                    isOutgoing: true,
                    timestamp: Date()
                )
            }
            .withLatestFrom(messagesRelay) { (newMessage, messages) -> [MessageItem] in
                var updatedMessages = messages
                updatedMessages.append(newMessage)
                return updatedMessages
            }
            .bind(to: messagesRelay)
            .disposed(by: disposeBag)
        
        // 处理粘贴事件
        let pasteboardContent = input.pasteAction
            .map { _ -> PasteboardContent in
                if let image = UIPasteboard.general.image {
                    return .image(image)
                } else if let text = UIPasteboard.general.string {
                    return .text(text)
                }
                return .none
            }
            .asDriver(onErrorJustReturn: .none)
        
        return Output(
            messages: messagesRelay.asDriver(),
            showImagePicker: input.selectImage.asDriver(onErrorJustReturn: ()),
            pasteboardContent: pasteboardContent
        )
    }
}

// 消息模型
public struct MessageItem {
    public let id: String
    public let content: String
    public let type: MessageType
    public let isOutgoing: Bool
    public let timestamp: Date
    
    public init(id: String, content: String, type: MessageType, isOutgoing: Bool, timestamp: Date) {
        self.id = id
        self.content = content
        self.type = type
        self.isOutgoing = isOutgoing
        self.timestamp = timestamp
    }
}

public enum MessageType {
    case text
    case image(UIImage)
}
