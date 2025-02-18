//
//  AppDelegate.swift
//  STImageCompressTool_Example
//
//  Created by stephenchen on 2025/01/23.
//

import UIKit
import STAllBase

#if DEBUG
import LookinServer
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 注册路由服务
        STRouterRegist.stRouterRegisterExecute()
        
        // Override point for customization after application launch.
        
        let win = UIWindow(frame: UIScreen.main.bounds)
        window = win
        
        let vc = ViewController()
        let nav = STBaseNavVC(rootViewController: vc)
        
        let vcMore = STViewControllerMore()
        let navMore = STBaseNavVC(rootViewController: vcMore)
        
        let tabVC = UITabBarController()
        tabVC.viewControllers = [nav, navMore]
        win.rootViewController = tabVC
        win.makeKeyAndVisible()
        
        return true
    }
}

