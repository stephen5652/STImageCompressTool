//
//  STAlbumVM.swift
//  STAlbumModule
//
//  Created by stephen Li on 2025/2/11.
//

import Foundation
import STRxInOutPutProtocol

class STAlbumVM: STViewModelProtocol {
    var disposeBag = RxSwift.DisposeBag()
    
    struct Input {
    }
    
    struct OutPut {
    }
    
    func transformInput(_ input: Input) -> OutPut {
        return OutPut()
    }
}
