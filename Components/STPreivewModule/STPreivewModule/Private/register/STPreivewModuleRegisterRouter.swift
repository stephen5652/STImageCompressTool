//
//  STPreivewModuleRegisterRouter.swift
//  STPreivewModule
//
//  Created by stephenchen on 2025/02/05.
//

import STAllBase
import STBaseModel

private class STPreivewModuleRegisterRouter: NSObject, STRouterRegisterProtocol {
    public static func stRouterRegisterExecute() {
        stRouterRegisterUrlParttern(STRouterDefine.kRouter_PreviewImage, nil) { (req: STRouterUrlRequest, com: STRouterUrlCompletion?) in
            let topVC: UIViewController? = UIViewController.mt_top()
            guard let topVC else {
                print("get top VC failed")
                return
            }
            
            guard let url = req.parameter[STRouterDefine.kRouterKey_Url] as? URL,
                  let item = req.parameter[STRouterDefine.kRouterKey_Item] as? ImageItem else {
                print("open Preview VC paramater error")
                return
            }
            
            let destVC = STPreviewVC(imageItem: item, url: url)
            DispatchQueue.main.async {
                if let nav = topVC.navigationController {
                    nav.pushViewController(destVC, animated: true)
                } else {
                    topVC.present(destVC, animated: true)
                }
            }
        }
    }
}

