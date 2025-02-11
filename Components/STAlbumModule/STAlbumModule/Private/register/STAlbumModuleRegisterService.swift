//
//  STAlbumModuleRegisterService.swift
//  STAlbumModule
//
//  Created by StephenChen on 2025/02/11.
//
import STModuleServiceSwift

private class STAlbumModuleRegisterService: NSObject, STModuleServiceRegisterProtocol {
    static func stModuleServiceRegistAction() {
        //注册服务 NSObject --> NSObjectProtocol   NSObjectProtocol为 swift 协议
//         STModuleService().stRegistModule(STAlbumModuleRegisterService.self, protocol: NSObjectProtocol.self, err: nil)
    }
}

// extension STAlbumModuleRegisterService: XXXXProtocol {
// static mehtod for XXXXProtocol
//     static func xxxxx() -> xxxxxObjc {
//         return XXXXX()
//     }
// }
