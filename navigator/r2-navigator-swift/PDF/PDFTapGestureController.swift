//
//  PDFTapGestureController.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 31/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import PDFKit

/// Since iOS 13, the way to add a properly functioning tap gesture recognizer on a `PDFView`
/// significantly changed. This class handles the setup depending on the current iOS version.
@available(iOS 11.0, *)
final class PDFTapGestureController: NSObject {
    
    private let tapRecognizer: UITapGestureRecognizer
    
    init(pdfView: PDFView, target: Any?, action: Selector?) {
        assert(pdfView.superview != nil, "The PDFView must be in the view hierarchy")
        
        tapRecognizer = UITapGestureRecognizer(target: target, action: action)

        super.init()
        
        if #available(iOS 13.0, *) {
            // If we add the gesture on the superview on iOS 13, then it will be triggered when
            // taping a link.
            // The delegate will be used to make sure that this recognizer has a lower precedence
            // over the default tap recognizer of the `PDFView`, which is used to handle links.
            tapRecognizer.delegate = self
            pdfView.addGestureRecognizer(tapRecognizer)
            
        } else {
            // Before iOS 13, the gesture must be on the superview to prevent conflicts.
            pdfView.superview?.addGestureRecognizer(tapRecognizer)
        }
    }
    
}

@available(iOS 11.0, *)
extension PDFTapGestureController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer == tapRecognizer
            && (otherGestureRecognizer as? UITapGestureRecognizer)?.numberOfTouchesRequired == tapRecognizer.numberOfTouchesRequired
    }
    
}
