//
//  STPreivewModuleRegisterService.swift
//  STPreivewModule
//
//  Created by stephenchen on 2025/02/05.
//
import STModuleServiceSwift

private class STPreivewModuleRegisterService: NSObject, STModuleServiceRegisterProtocol {
    static func stModuleServiceRegistAction() {
        //注册服务 NSObject --> NSObjectProtocol   NSObjectProtocol为 swift 协议
//         STModuleService().stRegistModule(STPreivewModuleRegisterService.self, protocol: NSObjectProtocol.self, err: nil)
    }
}

// extension STPreivewModuleRegisterService: XXXXProtocol {
// static mehtod for XXXXProtocol
//     static func xxxxx() -> xxxxxObjc {
//         return XXXXX()
//     }
// }
