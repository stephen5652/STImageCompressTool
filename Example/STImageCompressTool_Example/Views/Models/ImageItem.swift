import Photos

public struct ImageItem {
    public let asset: PHAsset
    public let compressedImageURL: URL?
    public var isCompressed: Bool { compressedImageURL != nil }
    
    public init(asset: PHAsset, compressedImageURL: URL? = nil) {
        self.asset = asset
        self.compressedImageURL = compressedImageURL
    }
}
