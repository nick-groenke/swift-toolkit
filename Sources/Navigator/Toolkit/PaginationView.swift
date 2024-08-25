//
//  File.swift
//  
//
//  Created by Nick Groenke on 8/24/24.
//

import Foundation
import UIKit

protocol PaginationView: UIView {
    var currentIndex: Int { get }
    var currentView: (UIView & PageView)? { get }
    var isUserInteractionEnabled: Bool { get set }
    var loadedViews: [Int: UIView & PageView] { get }
    var delegate: PaginationViewDelegate? { get set }
    
    func goToIndex(_ index: Int, location: PageLocation, options: NavigatorGoOptions) async -> Bool
    func reloadAtIndex(_ index: Int, location: PageLocation, pageCount: Int, readingProgression: ReadingProgression) async
}
