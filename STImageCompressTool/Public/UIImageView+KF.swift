//
//  UIImageView+KF.swift
//  STImageCompressTool
//
//  Created by Macintosh HD on 2025/2/5.
//

import Kingfisher
import CoreGraphics
import Foundation

#if SWIFT_PACKAGE
import KingfisherWebP_ObjC
#endif

/// 没有用 pod 集成的原因是 与 YYKit 内部的 WebP.framework 冲突？ 会造成崩溃
/// 使用源码集成手动
public struct WebPProcessor: ImageProcessor {

    public static let `default` = WebPProcessor()

    public let identifier = "com.yeatse.WebPProcessor"

    public init() {}

    public func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case .image(let image):
            return image
        case .data(let data):
            if data.isWebPFormat {
                let creatingOptions = ImageCreatingOptions(scale: options.scaleFactor, preloadAll: options.preloadAllAnimationData, onlyFirstFrame: options.onlyLoadFirstFrame)
                return KingfisherWrapper<KFCrossPlatformImage>.image(webpData: data, options: creatingOptions)
            } else {
                return DefaultImageProcessor.default.process(item: item, options: options)
            }
        }
    }
}


extension UIImageView {
    
    @nonobjc
    /// 设置网络图片的统一入口方法
    /// - Parameters:
    ///   - source: 可以传入 String 或者 URL 类型， 必须
    ///   - placeholder: 占位图，  在列表上使用的时候， 推荐放一张图片作为占位使用
    ///   - size: 图片解码到内存之前，按照大小去解码图片，解决大图 OOM 的问题。在已知图片大小的情况下，强烈建议使用该参数
    ///   - downsampling: 是否需要降低采样，默认需要，如果UIImageView自动布局获取不到对应宽高，需要设置为false，否则真实图片大小会有问题
    public func kfSetImage(
        url source: Any?,
        placeholder: UIImage? = nil,
        size: CGSize = .zero,
        downsampling:Bool = true,
        options: KingfisherOptionsInfo? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) {
            
            guard let source = source else {
                self.image = placeholder
                return
            }
            
            var defaultOptions: KingfisherOptionsInfo = [
                .scaleFactor(UIScreen.main.scale),
                .cacheOriginalImage
            ]
            
            if let options = options {
                defaultOptions += options
            }
            
            guard let url = self.url(from: source) else {
                self.image = placeholder
                return
            }
            
            setImage(with: url, placeholder: placeholder, size: size, downsampling: downsampling, options: &defaultOptions, completionHandler: completionHandler)
        }
    
    private func setImage(
        with url: URL,
        placeholder: UIImage?,
        size: CGSize,
        downsampling:Bool = true,
        options: inout KingfisherOptionsInfo,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) {
            
            if #available(iOS 14, *) {
                
                /// autolayout 取不到 size
                /// 在已经获取到容器大小的情况下，强制开启ImageIO图片下取样
                var size = size
                if size == .zero {
                    size = self.bounds.size
                }
                
                // 获取合适大小的图片展示
                if downsampling, !url.absoluteString.contains("gif"), size != CGSize.zero {
                    options += [.processor(DownsamplingImageProcessor(size: size))]
                }
            } else if url.absoluteString.contains("format,webp") {
                options += [.processor(WebPProcessor.default), .cacheSerializer(WebPSerializer.default)]
            }
            
            kf.setImage(with: url, placeholder: placeholder, options: options, completionHandler: completionHandler)
        }
    
    /// 管理本地图片
    public func kfSetImage(
        localPath path: String?,
        placeholder: UIImage? = nil,
        size: CGSize = .zero
    ) {
        guard let path = path else { return  }
        
        if #available(iOS 14, *) {} else {
            // ios 13 有webP 问题， 数量极少就不处理了
            image = UIImage(contentsOfFile: path)
            return
        }
        oc_kfSetImage(path: path, placeholderImage: placeholder, size: size, complete: nil)
    }
}

extension UIImageView {
    private func url(from source: Any?) -> URL? {
        if let urlString = source as? String {
            return URL(string: urlString)
        } else if let url = source as? URL {
            return url
        }
        return nil
    }
}

extension UIImageView {
    
    @objc
    /// 加载本地的图片
    /// - Parameter path: 本地路径
    public func oc_kfSetImage(path: String?, placeholderImage: UIImage?, size: CGSize, complete: ((UIImage?) -> Void)?) {
        guard let path = path else { return  }
        let url = URL(fileURLWithPath: path)
        
        let provider = LocalFileImageDataProvider(fileURL: url)
        
        var options: KingfisherOptionsInfo = [
            .scaleFactor(UIScreen.main.scale),
            .cacheOriginalImage
        ]
        // 获取合适大小的图片展示
        if !url.absoluteString.contains("gif"), size != CGSize.zero {
            options += [.processor(DownsamplingImageProcessor(size: size))]
        }
        
        kf.setImage(with: provider, placeholder: placeholderImage, options: options){ result in
            switch result {
            case .success(let value):
                complete?(value.image)
                
            case .failure(_):
                complete?(nil)
            }
        }
    }
    
    @objc
    ///  获取到图片
    public func kfSetImage(path: String?, complete: ((UIImage?) -> Void)?) {
        guard let path = path else { return  }
        let url = URL(fileURLWithPath: path)
        let provider = LocalFileImageDataProvider(fileURL: url)
        kf.setImage(with: provider) { result in
            switch result {
            case .success(let value):
                complete?(value.image)
                
            case .failure(_):
                complete?(nil)
            }
        }
    }
}

/// 这个是兼容 OC 的老代码使用的
extension UIImageView {
    /// 根据 url 设置图片
    /// - Parameter url: 图片地址
    @objc
    public func oc_setImage(url: URL?, placeholderImage: UIImage?) {
        guard let url = url else {
            print("kfSetImage url is nil!")
            return
        }
        kfSetImage(url: url, placeholder: placeholderImage)
    }
    
    @objc
    public func oc_setImage(url: URL?) {
        guard let url = url else {
            print("kfSetImage url is nil!")
            return
        }
        kfSetImage(url: url)
    }
    
    /// 根据 url 设置图片
    /// - Parameter url: 图片地址
    @objc
    public func oc_setImage(url: URL?, placeholderImage: UIImage?, size: CGSize) {
        guard let url = url else {
            print("kfSetImage url is nil!")
            return
        }
        kfSetImage(url: url, placeholder: placeholderImage, size: size)
    }
    
    /// 根据 url 设置图片
    /// - Parameter url: 图片地址
    /// -success: 成功的回调
    /// -failure: 失败的回调
    @objc
    public func oc_setImage(url: URL?, success: (() -> Void)?, failure: (() -> Void)?) {
        guard let url = url else {
            print("kfSetImage url is nil!")
            return
        }
        kfSetImage(url: url) { result in
            // 图片加载完成后的回调
            switch result {
            case .success(_):
                success?()
            case .failure(let error):
                // 图片加载失败
                failure?()
                print("Image loading failed with error: \(error)")
            }
        }
    }
}
