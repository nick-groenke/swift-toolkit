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
        scrollView.delegate = self
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    
    internal override func yOffsetForIndex(_ index: Int) -> CGFloat {
        scrollView.bounds.height * CGFloat(index)
    }

    /// Updates the current and pre-loaded views.
    internal override func setCurrentIndex(_ index: Int, location: PageLocation? = nil, completion: @escaping () -> Void = {}) {
        guard isEmpty || index != currentIndex else {
            completion()
            return
        }

        // If no explicit location is given, we'll load either the beginning or the end of the
        // resource depending on the last index. This allows to navigate backward across resources,
        // starting from the end of each previous resource.
        let movingBackward = (currentIndex - 1 == index)
        let location = location ?? (movingBackward ? .end : .start)

        currentIndex = index

        // To make sure that the views the most likely to be visible are loaded first, we first load
        // the current one, then the next ones and to finish the previous ones.
        scheduleLoadPage(at: index, location: location)
        let lastIndex = scheduleLoadPages(from: index, upToPositionCount: preloadNextPositionCount, direction: .forward, location: .start)
        let firstIndex = scheduleLoadPages(from: index, upToPositionCount: preloadPreviousPositionCount, direction: .backward, location: .end)

//        for (i, view) in loadedViews {
//            // Flushes the views that are not needed anymore.
//            guard firstIndex ... lastIndex ~= i else {
//                view.removeFromSuperview()
//                loadedViews.removeValue(forKey: i)
//                continue
//            }
//        }

        loadNextPage { [weak self] in
            if let self = self {
                self.delegate?.paginationViewDidUpdateViews(self)
                completion()
            }
        }
    }

    // MARK: - Navigation

    /// Go to the page view with given index.
    ///
    /// - Parameters:
    ///   - index: The index to move to.
    ///   - location: The location to move the future current page view to.
    /// - Returns: Whether the move is possible.
    override func goToIndex(_ index: Int, location: PageLocation, animated: Bool = false, completion: @escaping () -> Void) -> Bool {
        fatalError("not implemented")
    }
}

extension VerticalScrollPaginationView: UIScrollViewDelegate {
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


extension CGFloat {
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

extension UIColor {
    static func random() -> UIColor {
        return UIColor(
           red:   .random(),
           green: .random(),
           blue:  .random(),
           alpha: 1.0
        )
    }
}
