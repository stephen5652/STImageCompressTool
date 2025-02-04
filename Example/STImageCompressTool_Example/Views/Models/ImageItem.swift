import Photos

public struct ImageItem: Equatable {
    public let asset: PHAsset
    public let identifier: String
    public var compressedImageURL: URL?
    public var isCompressed: Bool {
        return compressedImageURL != nil
    }
    
    public init(asset: PHAsset, compressedImageURL: URL? = nil) {
        self.identifier = UUID().uuidString
        self.asset = asset
        self.compressedImageURL = compressedImageURL
    }
    
    /// 图片的文件大小--Byte
    /// @discussion: 此方法对于云中的相册文件获取不到大小
    public var imageFileSize: Int {
        get {
            let resource = PHAssetResource.assetResources(for: asset).first
            let result = resource?.value(forKey: "fileSize") as? Int ?? 0
            return result
        }
    }
    
    public static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        // 同时比较标识符和压缩URL的状态
        if lhs.identifier != rhs.identifier {
            return false
        }
        
        // 如果两者都没有压缩URL，认为是相等的
        if lhs.compressedImageURL == nil && rhs.compressedImageURL == nil {
            return true
        }
        
        // 如果其中一个有压缩URL而另一个没有，认为是不相等的
        if (lhs.compressedImageURL == nil) != (rhs.compressedImageURL == nil) {
            return false
        }
        
        // 如果都有压缩URL，比较URL是否相等
        return lhs.compressedImageURL == rhs.compressedImageURL
    }
}
