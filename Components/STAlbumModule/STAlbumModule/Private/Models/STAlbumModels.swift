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

struct PhotoInfo {
    let asset: PHAsset
    let thumbnail: UIImage?
} 