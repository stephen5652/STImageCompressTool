import Photos
import UIKit

struct ImageItem {
    let asset: PHAsset
    let compressedImageURL: URL?
    var isCompressed: Bool { compressedImageURL != nil }
    
    init(asset: PHAsset, compressedImageURL: URL? = nil) {
        self.asset = asset
        self.compressedImageURL = compressedImageURL
    }
} 