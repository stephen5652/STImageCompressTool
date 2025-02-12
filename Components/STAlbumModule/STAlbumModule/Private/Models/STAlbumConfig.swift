import UIKit

public struct STAlbumConfig {
    /// 每行显示的图片数量
    public var itemsPerRow: Int = 4
    /// 图片间距
    public var spacing: CGFloat = 1
    
    public init() {}
    
    /// 计算单个图片的尺寸
    public func itemSize(in width: CGFloat) -> CGSize {
        let totalSpacing = spacing * CGFloat(itemsPerRow + 1)  // 包括两边的间距
        let itemWidth = (width - totalSpacing) / CGFloat(itemsPerRow)
        return CGSize(width: itemWidth, height: itemWidth)
    }
    
    /// 获取布局配置
    public func flowLayout(in width: CGFloat) -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing
        layout.itemSize = itemSize(in: width)
        layout.sectionInset = UIEdgeInsets(
            top: spacing,
            left: spacing,
            bottom: spacing,
            right: spacing
        )
        return layout
    }
} 