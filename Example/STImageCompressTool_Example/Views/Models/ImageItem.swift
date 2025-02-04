import Photos

public struct ImageItem: Equatable {
    public let asset: PHAsset
    public let identifier: String
    public var compressedImageURL: URL?
    public var isCompressed: Bool {
        print("imageItem:\(asset.localIdentifier) imageUrl:\(String(describing: compressedImageURL))")
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
        return lhs.identifier == rhs.identifier
    }
}
