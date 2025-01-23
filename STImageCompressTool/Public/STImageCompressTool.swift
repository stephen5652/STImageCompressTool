//
//  STImageCompressTool.swift
//  Pod
//
//  Created by stephenchen on 2025/01/23.
//
// @_exported import XXXXXX //这个是为了对外暴露下层依赖的Pod

import UIKit

public struct STImageCompressTool {
    
    /// 压缩图片到指定文件大小以下
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxSize: 最大文件大小（单位：KB）
    /// - Returns: 压缩后的图片数据
    public static func compress(_ image: UIImage, toMaxFileSize maxSize: CGFloat) -> Data? {
        var compression: CGFloat = 1.0
        let maxFileSize = maxSize * 1024 // 转换为字节
        
        // 首先尝试用最高质量压缩
        guard var imageData = image.jpegData(compressionQuality: compression) else { return nil }
        
        // 如果已经小于目标大小，直接返回
        if CGFloat(imageData.count) <= maxFileSize { return imageData }
        
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
