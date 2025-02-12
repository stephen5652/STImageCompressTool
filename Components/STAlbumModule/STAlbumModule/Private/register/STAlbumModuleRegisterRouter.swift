//
//  STAlbumModuleRegisterRouter.swift
//  STAlbumModule
//
//  Created by StephenChen on 2025/02/11.
//

import STAllBase
import STComponentTools.STRouter
import STRoutServiceDefine

import Photos

private class STAlbumModuleRegisterRouter: NSObject, STRouterRegisterProtocol {
    public static func stRouterRegisterExecute() {
        stRouterRegisterUrlParttern(STRouterDefine.kRouter_AlbumList, nil) { (req: STRouterUrlRequest, com: STRouterUrlCompletion?) in
            let topVC = req.fromVC ?? UIViewController.mt_top()
            let vc = STAlbumListVC()
            vc.selectCallback = { (album: AlbumInfo) in
                if let completion = com {
                    let resp = STRouterUrlResponse.instance { b in
                        b.responseObj = [STRouterDefine.kRouterPara_Album :album]
                    }
                    
                    completion(resp)
                }
            }
            topVC.navigationController?.pushViewController(vc, animated: true)
        }

        stRouterRegisterUrlParttern(STRouterDefine.kRouter_Album, nil) { (req: STRouterUrlRequest, com: STRouterUrlCompletion?) in
            let topVC = req.fromVC ?? UIViewController.mt_top()
            let vc = STAlbumVC()
            topVC.navigationController?.pushViewController(vc, animated: true)
        }
        
        stRouterRegisterUrlParttern(STRouterDefine.kRouter_PhotoPreview, nil) { (req: STRouterUrlRequest, com: STRouterUrlCompletion?) in
            let topVC = req.fromVC ?? UIViewController.mt_top()
            
            guard let albumCollection = req.parameter[STRouterDefine.kRouterPara_AlbumCollection] as? PHAssetCollection else {
                
                return
            }
            
            let curIdx = req.parameter[STRouterDefine.kRouterPara_CurIdndex] as? IndexPath ?? IndexPath(row: 0, section: 0)
            
            let vc = STPhotoPreviewVC(collection: albumCollection, currentIndex: curIdx)
            topVC.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
}

