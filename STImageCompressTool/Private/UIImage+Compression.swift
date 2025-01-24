//
//  UIImage+Compression.swift
//  STImageCompressTool
//
//  Created by Macintosh HD on 2025/1/24.
//

import Foundation
import YYKit
import ImageIO
import UIKit


/// 图片压缩错误 上报到阿里云监测
@objc public enum CompressionError: Int, Error {
    case orientationFixFailed
    case resizeFailed
    case compressFailed
    case compressEncodeFailed
    case imageDataFailed
}

@objc
extension UIImage {
    
    /// 给图片添加圆角
    /// - Parameter cornerRadius: 圆半径
    /// - Returns:
    public func image(cornerRadius: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        if let ctx = UIGraphicsGetCurrentContext() {
            let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
            ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath)
            ctx.clip()
            draw(in: rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return newImage ?? self
        }
        
        return self
    }

    /// 图片压缩
    /// - Parameter imageData: 目标图片数据
    /// - Returns: 压缩结果
    @objc
    public static func lubanCompress(type: Int = 0, imageData: Data) throws -> Data {
        guard let image = UIImage(data: imageData) else {
            throw CompressionError.imageDataFailed
        }

        return try Self.lubanCompress(type: type, image: image)
    }

    /// 图片压缩
    /// - Parameters:
    /// - type: 编码类型： 1：webp，其他：jpg
    /// - image: 目标图片
    /// - Returns: 压缩结果
    @objc
    public static func lubanCompress(type: Int = 0, image: UIImage) throws -> Data {

        guard let imageData = compressEncode(type: type, image: image, quality: 1) else {
            throw CompressionError.compressEncodeFailed
        }

        let fixelW = image.size.width;
        let fixelH = image.size.height;

        var dataSize: CGFloat = 0

        var thumbW = Int(fixelW.truncatingRemainder(dividingBy: 2))  == 1 ? fixelW + 1 : fixelW;
        var thumbH = Int(fixelW.truncatingRemainder(dividingBy: 2))  == 1 ? fixelH + 1 : fixelH;

        let longSide = max(fixelW, fixelH)
        let shortSide = min(fixelW, fixelH)
        let scale = (shortSide/longSide);

        if (scale <= 1 && scale > 0.5625) {

            if (longSide < 1664) {
                if (imageData.count / 1024 < 150) {
                    return imageData;
                }
                dataSize = (fixelW * fixelH) / pow(1664, 2) * 150;
                dataSize = dataSize < 60 ? 60 : dataSize;
            }
            else if (longSide >= 1664 && longSide < 4990) {
                thumbW = fixelW / 2;
                thumbH = fixelH / 2;
                dataSize   = (thumbH * thumbW) / pow(2495, 2) * 300;
                dataSize = dataSize < 60 ? 60 : dataSize;
            }
            else if (longSide >= 4990 && longSide < 10240) {
                thumbW = fixelW / 4;
                thumbH = fixelH / 4;
                dataSize = (thumbW * thumbH) / pow(2560, 2) * 300;
                dataSize = dataSize < 100 ? 100 : dataSize;
            }
            else {
                let multiple = longSide / 1280 == 0 ? 1 : longSide / 1280;
                thumbW = fixelW / multiple;
                thumbH = fixelH / multiple;
                dataSize = (thumbW * thumbH) / pow(2560, 2) * 300;
                dataSize = dataSize < 100 ? 100 : dataSize;
            }
        }
        else if (scale <= 0.5625 && scale > 0.5) {

            if (fixelH < 1280 && imageData.count/1024 < 200) {

                return imageData;
            }
            let multiple = longSide / 1280 == 0 ? 1 : longSide / 1280;
            thumbW = fixelW / multiple;
            thumbH = fixelH / multiple;
            dataSize = (thumbW * thumbH) / (1440.0 * 2560.0) * 400;
            dataSize = dataSize < 100 ? 100 : dataSize;
        }
        else {
            let multiple = ceil(longSide / (1280.0 / scale));
            thumbW = fixelW / multiple;
            thumbH = fixelH / multiple;
            dataSize = ((thumbW * thumbH) / (1280.0 * (1280 / scale))) * 500;
            dataSize = dataSize < 100 ? 100 : dataSize;
        }

        return try UIImage.compress(type: type, image: image, width: thumbW, height: thumbH, dataSize: dataSize)
    }

    /// 执行压缩（固定压缩质量）
    /// - Parameters:
    ///   - image: 图片
    ///   - width: 宽度
    ///   - height: 高度
    ///   - size: 内存大小
    /// - Returns: 压缩后的数据
    private static func compress(type: Int, image: UIImage, width: CGFloat, height: CGFloat, dataSize: CGFloat) throws -> Data {
        guard let tempImage = image.fixOrientation() else {
            print("image fix orientation failed")
            throw CompressionError.orientationFixFailed
        }
        
        guard let imageData = compressEncode(type: type, image: image, quality: 1) else {
            throw CompressionError.compressEncodeFailed
        }

        guard let thumbImage = UIImage.resizeImgData(imageData as CFData, width: width, height: height) else {
            print("image resize failed")
            throw CompressionError.resizeFailed
        }

        guard let compressedData = compressEncode(type: type, image: thumbImage, quality: 0.6) else {
            print("image compress failed")
            throw CompressionError.compressFailed
        }

        return compressedData
    }
    
    /// 压缩图片（压缩到指定大小 - 一般用于外部分享对图片缩略图有要求的场景）maxFileSize : bytes,如果限制 64k -> 64000
    @objc
    public static func compressImage(_ image: UIImage, toMaxFileSize maxFileSize: Int) -> Data? {
        var compression: CGFloat = 1.0
        guard var imageData = image.jpegData(compressionQuality: compression) else {
            return nil
        }
        
        if imageData.count <= maxFileSize {
            return imageData
        }
        
        var max: CGFloat = 1.0
        var min: CGFloat = 0.0
        var times = 0
        var sizeBefore = imageData.count
        while imageData.count > maxFileSize && compression > 0.0 {
            compression = (max + min) / 2.0
            if let data = compressImageData(imageData, compression: compression) {
                imageData = data
            }
            if imageData.count < maxFileSize {
                min = compression
            } else {
                max = compression
            }
            times += 1
            let sizeAfter = imageData.count
            print("UIImage compressImageData times: \(times) compression: \(compression) sizeBefore: \(sizeBefore), sizeAfter: \(sizeAfter)")
            sizeBefore = sizeAfter
        }
        
        // 如果通过调整 JPEG 压缩质量仍然不能满足大小要求，则递归减小分辨率
        if imageData.count > maxFileSize {
            let ratio = CGFloat(maxFileSize) / CGFloat(imageData.count)
            let newSize = CGSize(width: image.size.width * sqrt(ratio), height: image.size.height * sqrt(ratio))
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resizedImage = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            
            return compressImage(resizedImage, toMaxFileSize: maxFileSize)
        }
        
        return imageData
    }
    
    /// 同步压缩图片到指定压缩系数，仅支持 JPG
    ///
    /// - Parameters:
    ///   - rawData: 原始图片数据
    ///   - compression: 压缩系数
    /// - Returns: 处理后数据
    static func compressImageData(_ rawData:Data, compression:Double) -> Data?{
        guard compression > 0.0, compression < 1.0 else {
            print("UIImage compressImageData error. compression must be between 0.0 and 1.0")
            return nil
        }

        return autoreleasepool {
            guard let imageSource = CGImageSourceCreateWithData(rawData as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let writeData = CFDataCreateMutable(nil, 0),
                  let imageType = CGImageSourceGetType(imageSource),
                  let imageDestination = CGImageDestinationCreateWithData(writeData, imageType, 1, nil) else {
                print("UIImage compressImageData failed to create image source or destination")
                return nil
            }

            print("UIImage compressImageData rawData = \(rawData.count) compression = \(compression) imageType = \(imageType)")

            let frameProperties = [kCGImageDestinationLossyCompressionQuality: compression] as CFDictionary
            CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, frameProperties)
            guard CGImageDestinationFinalize(imageDestination) else {
                print("UIImage compressImageData Failed to finalize image destination")
                return nil
            }
            return writeData as Data
        }
    }


    /// 压缩图片（动态计算压缩质量）
    /// - Parameters:
    ///   - type: 类型
    ///   - image: 图片
    ///   - dataSize: 图片大小
    /// - Returns: 压缩结果
    private static func compressMoreQuality(type: Int, image: UIImage, dataSize:CGFloat) -> Data? {

        var thumbImage = image

        var qualityCompress: CGFloat = 1.0;
        var loopCount = 0
        var startTs = Date().timeIntervalSince1970
        if var imageData = compressEncode(type: type, image: thumbImage, quality: qualityCompress) {

            print("loop entry duration = \(Date().timeIntervalSince1970 - startTs)")
            var length: CGFloat = CGFloat(imageData.count)

            startTs = Date().timeIntervalSince1970

            while (length / 1024 > dataSize && qualityCompress >= 0.06) {

                let ratio =  length / 1024 / dataSize
                if ratio > 2 && qualityCompress / 2 > 0.06 {
                    qualityCompress /= 2
                } else {
                    qualityCompress -= 0.06
                }

                autoreleasepool {
                    if let data = compressEncode(type: type, image: thumbImage, quality: qualityCompress), let image = UIImage(data: imageData) {
                        print("\(loopCount) time loop duration = \(Date().timeIntervalSince1970 - startTs)")
                        startTs = Date().timeIntervalSince1970
                        imageData    = data
                        length       = CGFloat(imageData.count)
                        thumbImage = image
                    }
                }
                loopCount += 1
            }

            print("loopCount = \(loopCount)")
            return imageData
        }
        return nil
    }


    /// 递归压缩图片质量
    /// - Parameters:
    ///   - type: 压缩类型
    ///   - data: 图片数据
    ///   - image: 图片
    ///   - currentSize: 当前大小
    ///   - expectedSize: 期望大小
    /// - Returns: 压缩结果
    private static func qualityCompress(type: Int, data: Data?, image: UIImage?, expectedSize:CGFloat) -> Data? {

        guard let data = data, let image = image else {
            return nil
        }

        let currentSize = CGFloat(data.count) / 1024

        if currentSize < expectedSize {
            return data
        }

        var quality: CGFloat = 1
        if currentSize / expectedSize >= 2 {
            quality = 0.5
        } else {
            quality = 1 - 0.06
        }

        if let compress = compressEncode(type: type, image: image, quality: quality), let image = UIImage(data: compress) {
            return qualityCompress(type: type, data: compress, image: image, expectedSize: expectedSize)
        } else {
            return data
        }
    }

    /// 根据指定编码压缩图片质量
    /// - Parameters:
    ///   - type: 编码类型： 1：webp，其他：jpg
    ///   - image: 图片
    ///   - quality: 质量
    /// - Returns: 压缩结果
    public static func compressEncode(type: Int, image: UIImage, quality: CGFloat) -> Data? {
        //        print("compressEncode quality = \(quality)")
        var data: Data? = nil
        let startDate = Date()
        autoreleasepool {
//            if type == 1 {
                print("compress onece-1:\(quality)")
                data = YYImageEncoder.encode(image, type:.JPEG, quality:quality)
//            } else {
//                print("compress onece-2:\(quality)")
//                data = image.jpegData(compressionQuality: quality)
//            }
//            if data == nil {
//                print("compress onece-3:\(quality)")
//                data = image.compressionAllType(with: quality)
//            }
        }
        print("compress onece-1 result[\(Date().timeIntervalSince(startDate))]:\(data?.count)")
        return data
    }

    var cgImageOrientation: CGImagePropertyOrientation { .init(imageOrientation) }

    /// ImageIO
    public func compressionAllType(with compressionQuality: CGFloat = 1) -> Data? {
         guard
             let mutableData = CFDataCreateMutable(nil, 0),
             let destination = CGImageDestinationCreateWithData(mutableData, "public.heic" as CFString, 1, nil),
             let cgImage = cgImage
         else { return nil }
         CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: compressionQuality, kCGImagePropertyOrientation: cgImageOrientation.rawValue] as CFDictionary)
         guard CGImageDestinationFinalize(destination) else { return nil }
        print("create finalsize")
         return mutableData as Data
     }

    /// 重置图片大小 使用 ImageIO 性能更好， 降低内存峰值 ， 上传大小降低 7 倍
    /// [I] oss>>> image compress before size = 2092 Kb
    /// [I] oss>>> image compress after size = 327 Kb
    /// - Parameters:
    ///   - image: 图片
    ///   - width: 宽度
    ///   - height: 高度
    /// - Returns: 重置后的图片
    public static func resize(image: UIImage, width:CGFloat, height:CGFloat) -> UIImage? {
        var startDate = Date()
        print("start resize： image-->Data")
        var data = image.pngData()
        var sec = Date().timeIntervalSince(startDate)
        startDate = Date()
        print("start resize--2： image-->Data[\(sec)]")

        if data == nil {
            data = image.compressionAllType()
        }
        
        guard let imageData = data as CFData? else { return image }
        return resizeImgData(imageData, width: width, height: height) ?? image
    }
    
    private static func resizeImgData(_ imageData: CFData, width:CGFloat, height:CGFloat) -> UIImage? {
        // 将UIImage转换为Data
        print("create imagesource")
        // 创建CGImageSource
        guard let imageSource = CGImageSourceCreateWithData(imageData, nil) else { return nil }
        
        // 设置缩略图选项
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ]
        
        print("start imagesource")
        // 创建缩略图
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        print("finish imagesource")

        return UIImage(cgImage: thumbnail)
    }
    
    /// 适配图片方向
    /// - Returns: 适配后的图片
    @objc
    public func fixOrientation() -> UIImage? {
        // No-op if the orientation is already correct
        if (self.imageOrientation == .up) {
            return self
        }

        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform: CGAffineTransform = .identity;

        switch (self.imageOrientation) {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: self.size.height);
            transform = transform.rotated(by: Double.pi);

        case .left, .leftMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0);
            transform = transform.rotated(by: Double.pi / 2);

        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: self.size.height);
            transform = transform.rotated(by: -(Double.pi / 2));
        default:
            break
        }

        switch (self.imageOrientation) {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0);
            transform = transform.scaledBy(x: -1, y: 1);

        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: self.size.height, y: 0);
            transform = transform.scaledBy(x: -1, y: 1);
        default: break
        }

        // Now we draw the underlying CGImage into a new context, applying the transform
        // calculated above.
        guard let imageRef = self.cgImage, let space = imageRef.colorSpace, let context = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: imageRef.bitsPerComponent, bytesPerRow: 0, space: space, bitmapInfo: imageRef.bitmapInfo.rawValue) else {
            return nil
        }

        context.concatenate(transform)
        switch (self.imageOrientation) {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(imageRef, in: CGRect(x: 0, y: 0, width: self.size.height, height: self.size.width))

        default:
            context.draw(imageRef, in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        }

        // And now we just create a new UIImage from the drawing context
        guard let cgimg = context.makeImage() else {
            return nil
        }
        let img = UIImage(cgImage: cgimg)
        return img
    }

}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        @unknown default:
            fatalError()
        }
    }
}
