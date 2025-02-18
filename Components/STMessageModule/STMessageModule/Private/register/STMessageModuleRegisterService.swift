//
//  STMessageModuleRegisterService.swift
//  STMessageModule
//
//  Created by StephenChen on 2025/02/18.
//
import STModuleServiceSwift

private class STMessageModuleRegisterService: NSObject, STModuleServiceRegisterProtocol {
    static func stModuleServiceRegistAction() {
        //注册服务 NSObject --> NSObjectProtocol   NSObjectProtocol为 swift 协议
//         STModuleService().stRegistModule(STMessageModuleRegisterService.self, protocol: NSObjectProtocol.self, err: nil)
    }
}

// extension STMessageModuleRegisterService: XXXXProtocol {
// static mehtod for XXXXProtocol
//     static func xxxxx() -> xxxxxObjc {
//         return XXXXX()
//     }
// }
