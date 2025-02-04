import Photos

public struct ImageItem: Equatable {
    public enum ImageType: String {
        case gif = "gif"
        case jpg = "jpg"
    }
    
    public let asset: PHAsset
    public let identifier: String
    public let imageFileSize: Int
    public let imageType: ImageType

    public var compressedTime: TimeInterval?
    
    public init(asset: PHAsset, imageFileSize: Int = 0) {
        self.asset = asset
        self.imageType = (PHAssetResource.assetResources(for: asset).first?.uniformTypeIdentifier ?? "") .lowercased().contains("gif") ? .gif : .jpg
        self.identifier = UUID().uuidString
        self.imageFileSize = imageFileSize
    }
    
    public var orignalImageUrl: URL {
        let resultUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(identifier)_original.\(imageType.rawValue)")
        return resultUrl
    }
    
    public var compressedImageURL: URL {
        let result = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(identifier)_compressed.\(imageType.rawValue)")
        return result
    }
    
    public static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        // 同时比较标识符和压缩URL的状态
        if lhs.identifier != rhs.identifier {
            return false
        }
        
        // 如果两者都没有压缩URL，认为是相等的
        if lhs.compressedTime == nil && rhs.compressedTime == nil {
            return true
        }
        
        // 如果其中一个有压缩URL而另一个没有，认为是不相等的
        if (lhs.compressedTime == nil) != (rhs.compressedTime == nil) {
            return false
        }
        
        // 如果都有压缩URL，比较URL是否相等
        return lhs.compressedTime == rhs.compressedTime
    }
}
