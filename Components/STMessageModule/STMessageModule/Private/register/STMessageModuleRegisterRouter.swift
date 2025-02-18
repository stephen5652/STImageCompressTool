//
//  STMessageModuleRegisterRouter.swift
//  STMessageModule
//
//  Created by StephenChen on 2025/02/18.
//

import  STComponentTools.STRouter
import STRoutServiceDefine
import MTCategoryComponent

private class STMessageModuleRegisterRouter: NSObject, STRouterRegisterProtocol {
    public static func stRouterRegisterExecute() {
        stRouterRegisterUrlParttern(STRouterDefine.kRouter_Message, nil) { (req: STRouterUrlRequest, com: STRouterUrlCompletion?) in
            let topVC: UIViewController? = req.fromVC ?? UIViewController.mt_top()
            let vc = STMessageSendVC()
            topVC?.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

