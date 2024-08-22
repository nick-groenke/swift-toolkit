//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import UIKit

final class VerticalScrollPaginationView: PaginationView {

    override init(frame: CGRect, preloadPreviousPositionCount: Int, preloadNextPositionCount: Int) {
        super.init(frame: frame, preloadPreviousPositionCount: preloadPreviousPositionCount, preloadNextPositionCount: preloadNextPositionCount)

        scrollView.isPagingEnabled = false
        scrollView.contentSize = CGSize(width: scrollView.frame.size.width, height: 500000)
        // TODO continuous - do I need this?
        insetsLayoutMarginsFromSafeArea = false
    }

    override public func layoutSubviews() {
        guard !loadedViews.isEmpty else {
            scrollView.contentSize = bounds.size
            return
        }
        
        let width = scrollView.frame.size.width

        var verticalOffset = 0
        for view in orderedViews {
            view.frame = CGRect(origin: CGPoint(x: 0, y: verticalOffset), size: CGSize(width: width, height: view.contentHeight()))
            verticalOffset += Int(view.frame.height)
            view.backgroundColor = .random()
        }
    }
    
    override internal func yOffsetForIndex(_ index: Int) -> CGFloat {
        scrollView.bounds.height * CGFloat(index)
    }
}

// Conformance to UIScrollViewDelegate
extension VerticalScrollPaginationView {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollView.isScrollEnabled = true

        let currentOffset = scrollView.contentOffset.y
        var vidx = 0
        var vCumul = 0.0
        var idx = 0
        var contentPixels = 0.0
        var found = false
        for view in orderedViews {
            vCumul += view.frame.height
            if (contentPixels + view.frame.height) <= currentOffset {
                contentPixels += view.frame.height
                if (!found) {
                    idx += 1
                }
            } else {
                found = true
            }
            vidx += 1
        }

        if currentIndex != idx {
            log(.info, "scrolled to \(currentOffset) index = \(idx) (old idx was \(currentIndex))")
        }
        setCurrentIndex(idx)
    }
}
