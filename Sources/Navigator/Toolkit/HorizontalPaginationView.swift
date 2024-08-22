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
        scrollView.delegate = self
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
    internal override func xOffsetForIndex(_ index: Int) -> CGFloat {
        (readingProgression == .rtl)
            ? scrollView.contentSize.width - (CGFloat(index + 1) * scrollView.bounds.width)
            : scrollView.bounds.width * CGFloat(index)
    }

    /// Queue views to be loaded until reaching the given number of pre-loaded positions.
    ///
    /// - Parameters:
    ///   - positionCount: Number of positions to pre-load before stopping.
    ///   - sourceIndex: Starting page index from which to pre-load the views.
    ///   - direction: The direction in which to load the views from the sourceIndex.
    /// - Returns: The last page index to be loaded after reaching the requested number of positions.
    internal override func scheduleLoadPages(from sourceIndex: Int, upToPositionCount positionCount: Int, direction: PageIndexDirection, location: PageLocation) -> Int {
        let index = sourceIndex + direction.rawValue
        guard
            positionCount > 0,
            scheduleLoadPage(at: index, location: location),
            let indexPositionCount = delegate?.paginationView(self, positionCountAtIndex: index)
        else {
            return sourceIndex
        }

        return scheduleLoadPages(
            from: index,
            upToPositionCount: positionCount - indexPositionCount,
            direction: direction,
            location: location
        )
    }

    /// Queue a page to be loaded at the given index, if it's not already loaded.
    ///
    /// - Returns: Whether page is or will be loaded.
    @discardableResult
    internal override func scheduleLoadPage(at index: Int, location: PageLocation) -> Bool {
        guard 0 ..< pageCount ~= index else {
            return false
        }

        loadingIndexQueue.removeAll { $0.index == index }
        loadingIndexQueue.append((index: index, location: location))
        return true
    }

    // MARK: - Navigation

    /// Go to the page view with given index.
    ///
    /// - Parameters:
    ///   - index: The index to move to.
    ///   - location: The location to move the future current page view to.
    /// - Returns: Whether the move is possible.
    override func goToIndex(_ index: Int, location: PageLocation, animated: Bool = false, completion: @escaping () -> Void) -> Bool {
        guard 0 ..< pageCount ~= index else {
            return false
        }

        if currentIndex == index {
            scrollToView(at: index, location: location, completion: completion)
        } else {
            fadeToView(at: index, location: location, animated: animated, completion: completion)
        }
        return true
    }

    internal func fadeToView(at index: Int, location: PageLocation, animated: Bool, completion: @escaping () -> Void) {
        func fade(to alpha: CGFloat, completion: @escaping () -> Void) {
            if animated {
                UIView.animate(withDuration: 0.15, animations: {
                    self.alpha = alpha
                }) { _ in completion() }
            } else {
                self.alpha = alpha
                completion()
            }
        }

        fade(to: 0) {
            self.scrollToView(at: index, location: location) {
                fade(to: 1, completion: completion)
            }
        }
    }

    internal func scrollToView(at index: Int, location: PageLocation, completion: @escaping () -> Void) {
        guard currentIndex != index else {
            if let view = currentView {
                view.go(to: location, completion: completion)
            } else {
                completion()
            }
            return
        }

        scrollView.isScrollEnabled = true
        setCurrentIndex(index, location: location, completion: completion)

        scrollView.scrollRectToVisible(CGRect(
            origin: CGPoint(
                x: xOffsetForIndex(index),
                y: yOffsetForIndex(index)
            ),
            size: scrollView.frame.size
        ), animated: false)
    }
}

extension HorizontalPaginationView: UIScrollViewDelegate {
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

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollView.isScrollEnabled = true

        let currentOffset = (readingProgression == .rtl)
            ? scrollView.contentSize.width - (scrollView.contentOffset.x + scrollView.frame.width)
            : scrollView.contentOffset.x

        let newIndex = Int(round(currentOffset / scrollView.frame.width))

        setCurrentIndex(newIndex)
    }
}
