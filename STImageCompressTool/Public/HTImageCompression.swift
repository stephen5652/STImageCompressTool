//
//  HTImageCompression.swift
//  STImageCompressTool
//
//  Created by stephen Li on 2025/2/6.
//

import Foundation
import ImageIO
import UIKit

@objcMembers
public class HTImageCompression {
    /// 图片压缩错误 上报到阿里云监测
    @objc public enum CompressionError: Int, Error {
        case orientationFixFailed
        case resizeFailed
        case compressFailed
        case compressEncodeFailed
        case imageDataFailed
    }
    
    /// GIF 压缩， 默认最大2MB
    public static func compressGIFData(with rawData: Data, limitDataSize: Int = 1024 * 1024 * 10) -> Data? {
        return compressGIFDataExec(with: rawData, limitDataSize: limitDataSize)
    }

    /// 图片压缩
    /// - Parameters:
    /// - type: 编码类型： 1：webp，其他：jpg
    /// - imageData: 目标图片数据
    /// - Returns: 压缩结果
    public static func lubanCompress(type: Int = 0, imageData: Data) throws -> Data {
        guard let image = UIImage(data: imageData) else {
            throw CompressionError.imageDataFailed
        }
        
        return try lubanCompress(type: type, image: image)
    }
    
    /// 图片压缩
    /// - Parameters:
    /// - type: 编码类型： 1：webp，其他：jpg
    /// - image: 目标图片
    /// - Returns: 压缩结果
    public static func lubanCompress(type: Int = 0, image: UIImage) throws -> Data {
        let result:Result<Data, Error> = autoreleasepool {
            do {
                let compressData = try lubanCompressExec(type: type, image: image)
                return .success(compressData)
            } catch {
                return .failure(error)
            }
        }
        
        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Luban compression
private extension HTImageCompression {
    /// 鲁班压缩
    static func lubanCompressExec(type: Int = 0, image: UIImage) throws -> Data {
        /**
         1. 将图片转换为 Data， 获得图片在内存中的大小
         2. 按照鲁班算法，计算图片压缩后的尺寸
         3. 压缩图片
         */

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

        return try compress(type: type, imageData: imageData, width: thumbW, height: thumbH, dataSize: dataSize)
    }
    
    /// 压缩图片数据
    static func compress(type: Int, imageData: Data, width: CGFloat, height: CGFloat, dataSize: CGFloat) throws -> Data {
        /// 缩小图片尺寸
        guard let thumbImage = resizeImgData(imageData as CFData, width: width, height: height) else {
            print("image resize failed")
            throw CompressionError.resizeFailed
        }

        /// 降低图片质量
        guard let compressedData = compressEncode(type: type, image: thumbImage, quality: 0.6) else {
            print("image compress failed")
            throw CompressionError.compressFailed
        }

        return compressedData
    }

    /// 图片降低像素质量
    static func compressEncode(type: Int, image: UIImage, quality: CGFloat) -> Data? {
        var data: Data? = nil
        let startDate = Date()
        autoreleasepool {
            print("compress onece-2:\(quality)")
            data = image.jpegData(compressionQuality: quality)
            if data == nil {
                print("compress onece-3:\(quality)")
                data = compressionAllType(image: image, quality: quality)
            }
        }
        print("compress onece result[\(Date().timeIntervalSince(startDate))]:\(data?.count)")
        return data
    }
    
    
    static func createImageOrientation(_ uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        var result :CGImagePropertyOrientation = .up
        switch uiOrientation {
        case .up: result = .up
        case .upMirrored: result = .upMirrored
        case .down: result = .down
        case .downMirrored: result = .downMirrored
        case .left: result = .left
        case .leftMirrored: result = .leftMirrored
        case .right: result = .right
        case .rightMirrored: result = .rightMirrored
        @unknown default:
            fatalError()
        }
        
        return result
    }

    /// ImageIO 降低像素质量
    static func compressionAllType(image: UIImage, quality: CGFloat = 1) -> Data? {
         guard
             let mutableData = CFDataCreateMutable(nil, 0),
             let destination = CGImageDestinationCreateWithData(mutableData, "public.heic" as CFString, 1, nil),
             let cgImage = image.cgImage
         else { return nil }
        
        let cgImageOrientation: CGImagePropertyOrientation = createImageOrientation(image.imageOrientation)

        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: quality, kCGImagePropertyOrientation: cgImageOrientation.rawValue] as CFDictionary)
         guard CGImageDestinationFinalize(destination) else { return nil }
        print("create finalsize")
        return mutableData as Data
    }

    /// 图片缩小尺寸
    static func resizeImgData(_ imageData: CFData, width:CGFloat, height:CGFloat) -> UIImage? {
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
    
}

// MARK: - GIF
private extension HTImageCompression {
    /// GIF 压缩， 默认最大2MB
    static func compressGIFDataExec(with rawData: Data, limitDataSize: Int = 1024 * 1024 * 10) -> Data? {
        let result: Result<Data,Error> = autoreleasepool {
            guard rawData.count > limitDataSize else {
                return .success(rawData)
            }
            
            var resultData = rawData
            
            let type = contentTypeForImageData(data: resultData) ?? ""
            
            guard type == "image/gif" else {
                print("GIF compressImageData error type = \(type)")
                return .failure(CompressionError.imageDataFailed)
            }
            
            let sampleCount = fitSampleCount(data: resultData)
            if let data = compressImageData(resultData, sampleCount: sampleCount){
                resultData = data
            } else {
                return .failure(CompressionError.compressFailed)
            }
            if resultData.count <= limitDataSize {
                return .success(resultData)
            }
            
            let imageSize = imageSize(data: resultData)
            var longSideWidth = max(imageSize.height, imageSize.width)
            // 图片尺寸按比率缩小，比率按字节比例逼近
            while resultData.count > limitDataSize{
                let ratio = sqrt(CGFloat(limitDataSize) / CGFloat(resultData.count))
                longSideWidth *= ratio
                if let data = compressImageData(resultData, limitLongWidth: longSideWidth) {
                    resultData = data
                } else {
                    return .failure(CompressionError.compressFailed)
                }
            }
            return .success(resultData)
        }
        
        switch result {
        case .success(let data):
            return data
        case .failure(_):
            return nil
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
        let frameDurations = frameDurations(imageSource: imageSource)
        
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
    static func compressImageData(_ rawData:Data, limitLongWidth:CGFloat = 800) -> Data?{
        let imageSize = imageSize(data: rawData)
        guard max(imageSize.height, imageSize.width) > limitLongWidth else {
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
            let frameDurations = frameDurations(imageSource: imageSource)
            
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

//MARK: - Data tools
private extension HTImageCompression {
    static func imageSize(data: Data) -> CGSize{
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [AnyHashable: Any],
              let imageHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              let imageWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat else {
            return .zero
        }
        return CGSize(width: imageWidth, height: imageHeight)
    }
    
    static func fitSampleCount(data: Data) -> Int{
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
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
    
    static func contentTypeForImageData(data: Data) -> String? {
        var c: UInt8 = 0
        data.copyBytes(to: &c, count: 1)
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
                if data.count < 12 {
                    return nil
                }
                let testString = String(data: data.subdata(in: 0..<12), encoding: .ascii)
                if testString?.hasPrefix("RIFF") == true && testString?.hasSuffix("WEBP") == true {
                    return "image/webp"
                }
                return nil
            default:
                return nil
        }
    }
}

//MARK: - ImageResource tools
private extension HTImageCompression {
    static func frameDurationAtIndex(imageSource: CGImageSource, _ index: Int) -> Double{
        var frameDuration = Double(0.1)
        guard let frameProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [AnyHashable:Any], let gifProperties = frameProperties[kCGImagePropertyGIFDictionary] as? [AnyHashable:Any] else {
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
    
    static func frameDurations(imageSource: CGImageSource) -> [Double]{
        let frameCount = CGImageSourceGetCount(imageSource)
        return (0..<frameCount).map{ frameDurationAtIndex(imageSource: imageSource, $0) }
    }
}
