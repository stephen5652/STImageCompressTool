//
//  STPreviewVC.swift
//  STPreivewModule
//
//  Created by Macintosh HD on 2025/2/5.
//

import STAllBase
import STBaseModel

class STPreviewVC: STBaseVC {
    
    let imageItem: ImageItem
    let url: URL
    
    private lazy var imageView: AnimatedImageView = {
        let view = AnimatedImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    init(imageItem: ImageItem, url: URL) {
        self.imageItem = imageItem
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "预览"
        setupUI()
        loadImage()
    }
    
    private func setupUI() {
        view.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func loadImage() {
        print("preview image: \(url.path)")
        imageView.kfSetImage(localPath: url.path)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
