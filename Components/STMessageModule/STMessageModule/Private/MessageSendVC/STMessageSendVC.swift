//
//  STMessageSendVC.swift
//  STMessageModule
//
//  Created by stephen Li on 2025/2/18.
//

import STAllBase
import RxSwift
import RxCocoa
import SnapKit
import STComponentTools.STRouter

class STMessageSendVC: STBaseVCMvvm {
    var vm = STMessageSendVM()
    private let disposeBag = DisposeBag()
    
    private let messageInputView: BaseMessageInputView = {
        if #available(iOS 14.0, *) {
            return MessageInputView()
        } else {
            return BaseMessageInputView()
        }
    }()
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
        table.separatorStyle = .none
        table.backgroundColor = .systemGroupedBackground
        table.keyboardDismissMode = .interactive  // 允许交互式关闭键盘
        return table
    }()
    
    // 记录输入框底部约束
    private var inputViewBottomConstraint: Constraint?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "发送消息"
        setupUI()
        bindData()
        setupKeyboardObservers()
        setupTapGesture()  // 添加点击手势
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(tableView)
        view.addSubview(messageInputView)
        
        tableView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(messageInputView.snp.top)
        }
        
        messageInputView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.height.equalTo(50)
            inputViewBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).constraint
        }
    }
    
    private func setupKeyboardObservers() {
        // 监听键盘显示
        NotificationCenter.default.rx.notification(UIResponder.keyboardWillShowNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] notification in
                guard let self = self,
                      let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                    return
                }
                
                let keyboardHeight = keyboardFrame.height
                self.inputViewBottomConstraint?.update(offset: -keyboardHeight)
                
                UIView.animate(withDuration: duration) {
                    self.view.layoutIfNeeded()
                }
            })
            .disposed(by: disposeBag)
        
        // 监听键盘隐藏
        NotificationCenter.default.rx.notification(UIResponder.keyboardWillHideNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] notification in
                guard let self = self,
                      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                    return
                }
                
                self.inputViewBottomConstraint?.update(offset: 0)
                
                UIView.animate(withDuration: duration) {
                    self.view.layoutIfNeeded()
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func setupTapGesture() {
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer()
        tableView.addGestureRecognizer(tapGesture)
        
        // 使用 RxGesture 处理点击事件
        tapGesture.rx.event
            .subscribe(onNext: { [weak self] _ in
                self?.view.endEditing(true)
            })
            .disposed(by: disposeBag)
        
        // 确保手势不影响 TableView 的其他点击事件
        tapGesture.cancelsTouchesInView = false
    }
    
    public func bindData() {
        let input = STMessageSendVM.Input(
            sendMessage: messageInputView.sendButton.rx.tap
                .withLatestFrom(messageInputView.textField.rx.text.orEmpty)
                .filter { !$0.isEmpty }
                .do(onNext: { [weak self] _ in
                    self?.messageInputView.textField.text = ""
                    self?.view.endEditing(true)
                }),
            sendImage: messageInputView.pasteImageSubject.asObservable(),
            selectImage: messageInputView.imageButton.rx.tap.asObservable(),
            pasteAction: messageInputView.pasteActionSubject.asObservable()
        )
        
        let output = vm.transformInput(input)
        
        // 绑定消息列表
        output.messages
            .drive(tableView.rx.items(cellIdentifier: "MessageCell", cellType: MessageCell.self)) { _, item, cell in
                cell.configure(with: item)
            }
            .disposed(by: disposeBag)
        
        // 新消息时滚动到底部
        output.messages
            .drive(onNext: { [weak self] _ in
                self?.scrollToBottom(animated: true)
            })
            .disposed(by: disposeBag)
        
        // 处理选择图片
        output.showImagePicker
            .drive(onNext: { [weak self] in
                self?.showImagePicker()
            })
            .disposed(by: disposeBag)
        
        // 监听 TableView 的滚动，收起键盘
        tableView.rx.contentOffset
            .filter { [weak self] _ in
                // 只在键盘显示时处理
                return self?.messageInputView.textField.isFirstResponder ?? false
            }
            .subscribe(onNext: { [weak self] _ in
                self?.view.endEditing(true)
            })
            .disposed(by: disposeBag)
        
        // 处理粘贴事件
        output.pasteboardContent
            .drive(onNext: { [weak self] content in
                guard let self = self else { return }
                switch content {
                case .none:
                    break
                case .text(let text):
                    if let selectedRange = self.messageInputView.textField.selectedTextRange {
                        self.messageInputView.textField.replace(selectedRange, withText: text)
                    } else {
                        let currentText = self.messageInputView.textField.text ?? ""
                        self.messageInputView.textField.text = currentText + text
                    }
                case .image(let image):
                    self.messageInputView.pasteImageSubject.onNext(image)
                    UIPasteboard.general.items = []
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func scrollToBottom(animated: Bool) {
        guard tableView.numberOfSections > 0 else { return }
        let section = tableView.numberOfSections - 1
        let row = tableView.numberOfRows(inSection: section) - 1
        guard row >= 0 else { return }
        
        let indexPath = IndexPath(row: row, section: section)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
    
    private func showImagePicker() {
        let req = STRouterUrlRequest.instance { builder in
            builder.urlToOpen = STRouterDefine.kRouter_AlbumList
        }
        
        stRouterOpenUrlRequest(req) { [weak self] (resp: STRouterUrlResponse) in
            // 处理选择的图片
        }
    }
}

// 基础输入视图
class BaseMessageInputView: UIView {
    let textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "输入消息..."
        tf.borderStyle = .roundedRect
        return tf
    }()
    
    let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("发送", for: .normal)
        return btn
    }()
    
    let imageButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "photo"), for: .normal)
        return btn
    }()
    
    // 添加图片粘贴事件
    let pasteImageSubject = PublishSubject<UIImage>()
    
    // 粘贴事件
    let pasteActionSubject = PublishSubject<Void>()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupPasteHandler()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        backgroundColor = .white
        
        addSubview(textField)
        addSubview(sendButton)
        addSubview(imageButton)
        
        textField.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.right.equalTo(imageButton.snp.left).offset(-10)
        }
        
        imageButton.snp.makeConstraints { make in
            make.right.equalTo(sendButton.snp.left).offset(-10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        sendButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.width.equalTo(50)
        }
    }
    
    private func setupPasteHandler() {
        // 监听粘贴板变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePasteboardChange),
            name: UIPasteboard.changedNotification,
            object: nil
        )
        
        // 设置 TextField 的代理
        textField.delegate = self
    }
    
    @objc private func handlePasteboardChange() {
        // 检查粘贴板是否有图片
        if UIPasteboard.general.hasImages {
            textField.placeholder = "可以粘贴图片"
        } else {
            textField.placeholder = "输入消息..."
        }
    }
}

extension BaseMessageInputView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 检查是否是粘贴操作
        if let paste = UIPasteboard.general.image {
            // 发送图片
            pasteImageSubject.onNext(paste)
            // 清空粘贴板
            UIPasteboard.general.items = []
            return false
        }
        return true
    }
}

// iOS 14 及以上版本的输入视图
@available(iOS 14.0, *)
class MessageInputView: BaseMessageInputView {
    private var contextMenuInteraction: UIContextMenuInteraction?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupModernTextFieldMenu()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupModernTextFieldMenu() {
        // 创建并添加上下文菜单交互
        let interaction = UIContextMenuInteraction(delegate: self)
        textField.addInteraction(interaction)
        self.contextMenuInteraction = interaction
        
        // 添加长按手势
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        textField.addGestureRecognizer(longPress)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        textField.becomeFirstResponder()
    }
}

@available(iOS 14.0, *)
extension MessageInputView: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ -> UIMenu? in
            var menuItems: [UIMenuElement] = []
            
            // 复制选项
            if self.textField.selectedTextRange != nil, 
               let text = self.textField.text, !text.isEmpty {
                menuItems.append(UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc")) { _ in
                    self.textField.copy(nil)
                })
            }
            
            // 粘贴选项
            if UIPasteboard.general.hasStrings || UIPasteboard.general.hasImages {
                menuItems.append(UIAction(title: "粘贴", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
                    self?.pasteActionSubject.onNext(())
                })
            }
            
            // 全选选项
            if let text = self.textField.text, !text.isEmpty {
                menuItems.append(UIAction(title: "全选", image: UIImage(systemName: "checkmark.circle")) { _ in
                    self.textField.selectAll(nil)
                })
            }
            
            return UIMenu(title: "", children: menuItems)
        }
    }
}

// 添加 String 扩展，用于检查是否为空
extension String {
    var isNilOrEmpty: Bool {
        return self.isEmpty
    }
}

// 消息 Cell
class MessageCell: UITableViewCell {
    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private let messageImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
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
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(messageImageView)
    }
    
    func configure(with item: MessageItem) {
        switch item.type {
        case .text:
            messageLabel.isHidden = false
            messageImageView.isHidden = true
            messageLabel.text = item.content
            
            // 文本消息的约束
            messageLabel.snp.remakeConstraints { make in
                make.edges.equalToSuperview().inset(12)
            }
            
            // 气泡约束
            bubbleView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview().inset(4)
                if item.isOutgoing {
                    make.right.equalToSuperview().offset(-12)
                    make.left.greaterThanOrEqualToSuperview().offset(60)
                } else {
                    make.left.equalToSuperview().offset(12)
                    make.right.lessThanOrEqualToSuperview().offset(-60)
                }
            }
            
        case .image(let image):
            messageLabel.isHidden = true
            messageImageView.isHidden = false
            messageImageView.image = image
            
            // 计算图片显示尺寸
            let maxWidth: CGFloat = UIScreen.main.bounds.width * 0.6
            let maxHeight: CGFloat = 200
            let imageSize = image.size
            let aspectRatio = imageSize.width / imageSize.height
            
            let finalWidth: CGFloat
            let finalHeight: CGFloat
            
            if aspectRatio > 1 {
                // 宽图
                finalWidth = min(maxWidth, imageSize.width)
                finalHeight = finalWidth / aspectRatio
            } else {
                // 长图
                finalHeight = min(maxHeight, imageSize.height)
                finalWidth = finalHeight * aspectRatio
            }
            
            // 图片消息的约束
            messageImageView.snp.remakeConstraints { make in
                make.width.equalTo(finalWidth)
                make.height.equalTo(finalHeight)
                make.edges.equalToSuperview()
            }
            
            // 气泡约束
            bubbleView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview().inset(4)
                make.width.equalTo(finalWidth)
                make.height.equalTo(finalHeight)
                if item.isOutgoing {
                    make.right.equalToSuperview().offset(-12)
                } else {
                    make.left.equalToSuperview().offset(12)
                }
            }
        }
        
        // 设置气泡样式
        bubbleView.backgroundColor = item.isOutgoing ? .systemBlue : .systemGray5
        messageLabel.textColor = item.isOutgoing ? .white : .black
    }
}
