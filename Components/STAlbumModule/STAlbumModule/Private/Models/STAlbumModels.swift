import Foundation
import Photos
import UIKit

struct AlbumInfo {
    let collection: PHAssetCollection
    let name: String
    let count: Int
    let identifier: String
    let createDate: Date
    let thumbnail: UIImage?
}

struct PhotoInfo: Equatable {
    let asset: PHAsset
    var thumbnail: UIImage?
    
    static func == (lhs: PhotoInfo, rhs: PhotoInfo) -> Bool {
        // 只比较 asset 的 localIdentifier，因为 UIImage 不遵循 Equatable
        return lhs.asset.localIdentifier == rhs.asset.localIdentifier
    }
} 