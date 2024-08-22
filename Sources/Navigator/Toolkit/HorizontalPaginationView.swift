//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import UIKit

final class HorizontalPaginationView: PaginationView {
    
    override init(frame: CGRect, preloadPreviousPositionCount: Int, preloadNextPositionCount: Int) {
        super.init(frame: frame, preloadPreviousPositionCount: preloadPreviousPositionCount, preloadNextPositionCount: preloadNextPositionCount)

        scrollView.isPagingEnabled = true
    }

    override public func layoutSubviews() {
        guard !loadedViews.isEmpty else {
            scrollView.contentSize = bounds.size
            return
        }

        let size = scrollView.bounds.size
        scrollView.contentSize = CGSize(width: size.width * CGFloat(pageCount), height: size.height)

        for (index, view) in loadedViews {
            view.frame = CGRect(origin: CGPoint(x: xOffsetForIndex(index), y: 0), size: size)
        }

        scrollView.contentOffset.x = xOffsetForIndex(currentIndex)
    }

    /// Returns the x offset to the page view with given index in the scroll view.
    override internal func xOffsetForIndex(_ index: Int) -> CGFloat {
        (readingProgression == .rtl)
            ? scrollView.contentSize.width - (CGFloat(index + 1) * scrollView.bounds.width)
            : scrollView.bounds.width * CGFloat(index)
    }
}

// Conformance to UIScrollViewDelegate
extension HorizontalPaginationView {
    /// We disable the scroll once the user releases the drag to prevent scrolling through more than 1 resource at a
    /// time. Otherwise, because the pagination view's scroll view would have the focus during the scroll gesture, the
    /// scrollable content of the resources would be skipped.
    /// Note: using this approach might provide a better experience:
    /// https://oleb.net/blog/2014/05/scrollviews-inside-scrollviews/

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        scrollView.isScrollEnabled = false
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollView.isScrollEnabled = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollView.isScrollEnabled = true
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollView.isScrollEnabled = true

        let currentOffset = (readingProgression == .rtl)
            ? scrollView.contentSize.width - (scrollView.contentOffset.x + scrollView.frame.width)
            : scrollView.contentOffset.x

        let newIndex = Int(round(currentOffset / scrollView.frame.width))

        setCurrentIndex(newIndex)
    }
}
