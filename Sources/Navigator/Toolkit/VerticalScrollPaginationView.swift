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
        log(.error, "LAYOUT SUBVIEWS")
        guard !loadedViews.isEmpty else {
            scrollView.contentSize = bounds.size
            return
        }
        
        let width = scrollView.frame.size.width

//        for (index, view) in loadedViews {
//            view.frame = CGRect(origin: CGPoint(x: 0, y: yOffsetForIndex(index)), size: CGSize(width: width, height: view.contentHeight()))
//            view.backgroundColor = .random()
//        }
        
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
//        log(.info, "Set current index = \(index); location = \(String(describing: location))")
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
        log(.info, "Go to index \(index); location = \(location)")
        // TODO continuous - not sure what this does or whether I need it.
        guard 0 ..< pageCount ~= index else {
            log(.info, "returning false")
            return false
        }
        scrollToView(at: index, location: location, completion: completion)
        return true
    }
    
    internal func scrollToView(at index: Int, location: PageLocation, completion: @escaping () -> Void) {
        // TODO continuous - what about deferring the move to the location if the view isn't loaded fully??
        // i.e. This from spread view's 'go' method
//        guard spreadLoaded else {
//            // Delays moving to the location until the document is loaded.
//            pendingLocation = location
//            return
//        }
        
        guard loadedViews[index] != nil else {
            print("TODO")
            return
        }
        
        let progression = switch location {
            case let .locator(locator): locator.locations.progression ?? 0
            case .start: 0.0
            case .end: 1.0
        }
        
        guard progression >= 0, progression <= 1 else {
            log(.warning, "Scrolling to invalid progression \(progression)")
            completion()
            return
        }
        
        setCurrentIndex(index, location: location, completion: completion)
        
        let targetView = loadedViews[index]!
        let targetViewOrigin = targetView.frame.origin
        let offsetInView = targetView.frame.height * progression
        let targetScrollOffset = targetViewOrigin.y + offsetInView
        
        let p = CGPoint(
            x: targetViewOrigin.x,
            y: targetScrollOffset
        )

        log(.info, "Scroll to \(p)")
        scrollView.contentOffset = p
        
        
        
        
        // Possibly the code needs to be the same regardless of whether currentIndex == index?
        // Horizontal version uses this guard, which makes sense since
//        guard currentIndex != index else {
//            if let view = currentView {
////                view.go(to: location, completion: completion)
//                
//                switch location {
//                case let .locator(locator):
//                    // 1. Find the offset for the spread view within this scroll view.
//                    // 2. Add the offset for the progression WITHIN the spread view.
//                    fatalError("not implemented")
//                case .start:
//                    // Scroll to view's offset
//                    fatalError("not implemented")
//                case .end:
//                    // Scroll to view's offset + view total height - one screen's worth.
//                    fatalError("not implemented")
//                }
//            } else {
//                completion()
//            }
//            return
//        }

        // Possibly this will work?
        

//        scrollView.scrollRectToVisible(CGRect(
//            origin: CGPoint(
//                x: xOffsetForIndex(index),
//                y: yOffsetForIndex(index)
//            ),
//            size: scrollView.frame.size
//        ), animated: false)
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
        // TODO continuous - Do I really need to call this constantly as I scroll?
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
