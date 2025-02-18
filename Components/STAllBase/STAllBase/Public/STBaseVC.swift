//
//  STBaseVC.swift
//  STAllBase
//
//  Created by Macintosh HD on 2025/2/5.
//

import UIKit

import STRxInOutPutProtocol
import CYLTabBarController

public typealias STBaseVCMvvm = STBaseVC & STMvvmProtocol

public class STBaseNavVC: CYLBaseNavigationController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.tintColor = UIColor.red
        navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.red]
    }
}

open class STBaseVC: CYLBaseViewController {

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        cyl_resetInteractivePopGestureRecognizer()
        navigationItem.backBarButtonItem?.title = ""
        // Do any additional setup after loading the view.
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
