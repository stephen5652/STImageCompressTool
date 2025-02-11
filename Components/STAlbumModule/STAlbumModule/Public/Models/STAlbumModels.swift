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
    
    init(collection: PHAssetCollection, name: String, count: Int, identifier: String, createDate: Date, thumbnail: UIImage?) {
        self.collection = collection
        self.name = name
        self.count = count
        self.identifier = identifier
        self.createDate = createDate
        self.thumbnail = thumbnail
    }
}

struct PhotoInfo {
    let asset: PHAsset
    let thumbnail: UIImage?
    
    init(asset: PHAsset, thumbnail: UIImage?) {
        self.asset = asset
        self.thumbnail = thumbnail
    }
} 
