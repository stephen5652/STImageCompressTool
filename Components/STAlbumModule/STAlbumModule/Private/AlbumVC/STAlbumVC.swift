//
//  STAlbumVC.swift
//  Pods
//
//  Created by stephen Li on 2025/2/11.
//

import STAllBase

class STAlbumVC: STBaseVCMvvm {
    var vm = STAlbumVM()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "相册"
        setUpUI()
        bindData()
    }
    
    private func setUpUI() {
        
    }
    
    func bindData() {
        
    }
}

extension STAlbumVC {
    
}
