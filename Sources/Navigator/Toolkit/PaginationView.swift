//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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

protocol PaginationViewDelegate: AnyObject {
    /// Creates the page view for the page at given index.
    func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)?

    /// Called when the page views were updated.
    func paginationViewDidUpdateViews(_ paginationView: PaginationView)

    /// Returns the number of positions (as in `Publication.positionList`) in the page view at given index.
    func paginationView(_ paginationView: PaginationView, positionCountAtIndex index: Int) -> Int
}
