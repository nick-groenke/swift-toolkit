//
//  File.swift
//  
//
//  Created by Nick Groenke on 8/21/24.
//

import Foundation

extension CGFloat {
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}
