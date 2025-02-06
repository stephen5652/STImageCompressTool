//
//  STImageCompressTool.swift
//  Pod
//
//  Created by stephenchen on 2025/01/23.
//
// @_exported import XXXXXX //这个是为了对外暴露下层依赖的Pod

import UIKit

public struct STImageCompressTool {
    public enum CompressStrategy {
        case normal    // 普通压缩，使用 ImageIO
        case luban     // Luban 压缩算法
        
        static func strategy(for imageData: Data) -> CompressStrategy {
            let fileSizeInMB = Double(imageData.count) / (1024 * 1024)
            return fileSizeInMB > 15 ? .luban : .normal
        }
    }
    
    /// 压缩图片到指定文件大小以下
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxSize: 最大文件大小（单位：KB）
    /// - Returns: 压缩后的图片数据
    public static func compress(_ image: UIImage, toMaxFileSize maxSize: CGFloat) -> Data? {
        // 获取原始图片数据
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            return nil
        }
        
        // 确定压缩策略
        let strategy = CompressStrategy.strategy(for: imageData)
        
        switch strategy {
        case .normal:
            return _compress_1(image, toMaxFileSize: maxSize)
        case .luban:
            do {
                return try UIImage.lubanCompress(image: image)
            } catch {
                print("❌ Luban压缩失败：\(error)")
                // 如果 Luban 压缩失败，回退到普通压缩
                return _compress_1(image, toMaxFileSize: maxSize)
            }
        }
    }
    
    private static func _compress_1(_ image: UIImage, toMaxFileSize maxSize: CGFloat) -> Data? {
        var compression: CGFloat = 1.0
        let maxFileSize = maxSize * 1024 // 转换为字节
        
        // 首先尝试用最高质量压缩
        guard var imageData = image.jpegData(compressionQuality: compression) else { return nil }
        
        // 如果已经小于目标大小，直接返回
        if CGFloat(imageData.count) <= maxFileSize {
            return imageData
        }
        
        // 二分法查找最佳压缩率
        var minCompression: CGFloat = 0
        var maxCompression: CGFloat = 1
        
        for _ in 0..<6 { // 最多尝试6次
            compression = (minCompression + maxCompression) / 2
            guard let data = image.jpegData(compressionQuality: compression) else { return nil }
            
            if CGFloat(data.count) < maxFileSize {
                minCompression = compression
            } else {
                maxCompression = compression
            }
            imageData = data
        }
        
        return imageData
    }
    
    
    
    /// 压缩图片到指定尺寸
    /// - Parameters:
    ///   - image: 原始图片
    ///   - targetSize: 目标尺寸
    /// - Returns: 压缩后的图片
    public static func resize(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

//
//  UIImage+GIF.swift
//  HelloExtensions
//
//  Created by Make on 2024.07.03.
//

import Foundation
import ImageIO

extension UIImage {
    
    /// GIF 压缩， 默认最大2MB
    public static func compressGIFData(with rawData: Data, limitDataSize: Int = 1024 * 1024 * 10) -> Data? {
        autoreleasepool {
            guard rawData.count > limitDataSize else {
                return rawData
            }
            
            var resultData = rawData
            
            let type = resultData.contentTypeForImageData() ?? ""
            
            guard type == "image/gif" else {
                print("GIF compressImageData error type = \(type)")
                return nil
            }
            
            
            let sampleCount = resultData.fitSampleCount
            if let data = compressImageData(resultData, sampleCount: sampleCount){
                resultData = data
            } else {
                return nil
            }
            if resultData.count <= limitDataSize {
                return resultData
            }
            
            var longSideWidth = max(resultData.imageSize.height, resultData.imageSize.width)
            // 图片尺寸按比率缩小，比率按字节比例逼近
            while resultData.count > limitDataSize{
                let ratio = sqrt(CGFloat(limitDataSize) / CGFloat(resultData.count))
                longSideWidth *= ratio
                if let data = compressImageData(resultData, limitLongWidth: longSideWidth) {
                    resultData = data
                } else {
                    return nil
                }
            }
            return resultData
        }
    }
    
    /// 同步压缩图片抽取帧数，仅支持 GIF
    ///
    /// - Parameters:
    ///   - rawData: 原始图片数据
    ///   - sampleCount: 采样频率，比如 3 则每三张用第一张，然后延长时间
    /// - Returns: 处理后数据
    static func compressImageData(_ rawData:Data, sampleCount:Int) -> Data?{
        guard let imageSource = CGImageSourceCreateWithData(rawData as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let writeData = CFDataCreateMutable(nil, 0),
              let imageType = CGImageSourceGetType(imageSource) else {
            return nil
        }
        
        // 计算帧的间隔
        let frameDurations = imageSource.frameDurations
        
        // 合并帧的时间,最长不可高于 200ms
        let mergeFrameDurations = (0..<frameDurations.count).filter{ $0 % sampleCount == 0 }.map{ min(frameDurations[$0..<min($0 + sampleCount, frameDurations.count)].reduce(0.0) { $0 + $1 }, 0.2) }
        
        // 抽取帧 每 n 帧使用 1 帧
        let sampleImageFrames = (0..<frameDurations.count).filter{ $0 % sampleCount == 0 }.compactMap{ CGImageSourceCreateImageAtIndex(imageSource, $0, nil) }
        
        guard let imageDestination = CGImageDestinationCreateWithData(writeData, imageType, sampleImageFrames.count, nil) else{
            return nil
        }
        
        // 设置压缩选项
        let destinationProperties = [
            kCGImageDestinationLossyCompressionQuality: 0.8,
            kCGImageDestinationOptimizeColorForSharing: true,
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFHasGlobalColorMap: true,
                kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
                kCGImagePropertyDepth: 8
            ]
        ] as CFDictionary
        
        CGImageDestinationSetProperties(imageDestination, destinationProperties)
        
        
        // 使用 autoreleasepool 减少内存占用
        autoreleasepool {
            zip(sampleImageFrames, mergeFrameDurations).forEach { frame, duration in
                let frameProperties = [kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: duration,
                    kCGImagePropertyGIFUnclampedDelayTime: duration,
                    kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
                    kCGImagePropertyDepth: 8
                ]] as CFDictionary
                
                CGImageDestinationAddImage(imageDestination, frame, frameProperties)
            }
        }
        
        guard CGImageDestinationFinalize(imageDestination) else {
            return nil
        }
        
        return writeData as Data
    }
    
    /// 同步压缩图片数据长边到指定数值
    ///
    /// - Parameters:
    ///   - rawData: 原始图片数据
    ///   - limitLongWidth: 长边限制
    /// - Returns: 处理后数据
    public static func compressImageData(_ rawData:Data, limitLongWidth:CGFloat = 800) -> Data?{
        guard max(rawData.imageSize.height, rawData.imageSize.width) > limitLongWidth else {
            return rawData
        }
        
        guard let imageSource = CGImageSourceCreateWithData(rawData as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let writeData = CFDataCreateMutable(nil, 0),
              let imageType = CGImageSourceGetType(imageSource) else {
            return nil
        }
        
        
        let frameCount = CGImageSourceGetCount(imageSource)
        
        guard let imageDestination = CGImageDestinationCreateWithData(writeData, imageType, frameCount, nil) else{
            return nil
        }
        
        // 设置缩略图参数，kCGImageSourceThumbnailMaxPixelSize 为生成缩略图的大小。当设置为 800，如果图片本身大于 800*600，则生成后图片大小为 800*600，如果源图片为 700*500，则生成图片为 800*500
        let options = [
            kCGImageSourceThumbnailMaxPixelSize: limitLongWidth,
            kCGImageSourceCreateThumbnailWithTransform:true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent:true
        ] as CFDictionary
        
        if frameCount > 1 {
            // 计算帧的间隔
            let frameDurations = imageSource.frameDurations
            
            // 每一帧都进行缩放
            let resizedImageFrames = (0..<frameCount).compactMap{ CGImageSourceCreateThumbnailAtIndex(imageSource, $0, options) }
            
            // 每一帧都进行重新编码
            zip(resizedImageFrames, frameDurations).forEach {
                // 设置帧间隔
                let frameProperties = [kCGImagePropertyGIFDictionary : [kCGImagePropertyGIFDelayTime: $1, kCGImagePropertyGIFUnclampedDelayTime: $1]]
                CGImageDestinationAddImage(imageDestination, $0, frameProperties as CFDictionary)
            }
        } else {
            guard let resizedImageFrame = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) else {
                return nil
            }
            CGImageDestinationAddImage(imageDestination, resizedImageFrame, nil)
        }
        
        guard CGImageDestinationFinalize(imageDestination) else {
            return nil
        }
        
        return writeData as Data
    }
    
    
}
extension CGImageSource {
    func frameDurationAtIndex(_ index: Int) -> Double{
        var frameDuration = Double(0.1)
        guard let frameProperties = CGImageSourceCopyPropertiesAtIndex(self, index, nil) as? [AnyHashable:Any], let gifProperties = frameProperties[kCGImagePropertyGIFDictionary] as? [AnyHashable:Any] else {
            return frameDuration
        }
        
        if let unclampedDuration = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber {
            frameDuration = unclampedDuration.doubleValue
        } else {
            if let clampedDuration = gifProperties[kCGImagePropertyGIFDelayTime] as? NSNumber {
                frameDuration = clampedDuration.doubleValue
            }
        }
        
        if frameDuration < 0.011 {
            frameDuration = 0.1
        }
        
        return frameDuration
    }
    
    var frameDurations:[Double]{
        let frameCount = CGImageSourceGetCount(self)
        return (0..<frameCount).map{ self.frameDurationAtIndex($0) }
    }
}

extension Data {
    var imageSize:CGSize{
        guard let imageSource = CGImageSourceCreateWithData(self as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [AnyHashable: Any],
              let imageHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              let imageWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat else {
            return .zero
        }
        return CGSize(width: imageWidth, height: imageHeight)
    }
    
    var fitSampleCount:Int{
        guard let imageSource = CGImageSourceCreateWithData(self as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return 1
        }
        
        let frameCount = CGImageSourceGetCount(imageSource)
        var sampleCount = 1
        switch frameCount {
            case 2..<8:
                sampleCount = 2
            case 8..<20:
                sampleCount = 3
            case 20..<30:
                sampleCount = 4
            case 30..<40:
                sampleCount = 5
            case 40..<Int.max:
                sampleCount = 6
            default:break
        }
        
        return sampleCount
    }
    
    func contentTypeForImageData() -> String? {
        var c: UInt8 = 0
        self.copyBytes(to: &c, count: 1)
        switch c {
            case 0xFF:
                return "image/jpeg"
            case 0x89:
                return "image/png"
            case 0x47:
                return "image/gif"
            case 0x49, 0x4D:
                return "image/tiff"
            case 0x52:
                // R as RIFF for WEBP
                if self.count < 12 {
                    return nil
                }
                let testString = String(data: self.subdata(in: 0..<12), encoding: .ascii)
                if testString?.hasPrefix("RIFF") == true && testString?.hasSuffix("WEBP") == true {
                    return "image/webp"
                }
                return nil
            default:
                return nil
        }
    }
}
