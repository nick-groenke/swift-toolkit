//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import UIKit

enum PageLocation: Equatable {
    case start
    case end
    case locator(Locator)

    init(_ locator: Locator?) {
        self = locator.map { .locator($0) }
            ?? .start
    }

    var isStart: Bool {
        switch self {
        case .start:
            return true
        case let .locator(locator) where locator.locations.progression ?? 0 == 0:
            return true
        default:
            return false
        }
    }
}

protocol PageView {
    /// Moves the page to the given internal location.
    func go(to location: PageLocation, completion: (() -> Void)?)
    func contentHeight() -> CGFloat
}

extension PageView {
    func go(to location: PageLocation) {
        go(to: location, completion: nil)
    }
}

protocol PaginationViewDelegate: AnyObject {
    /// Creates the page view for the page at given index.
    func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)?

    /// Called when the page views were updated.
    func paginationViewDidUpdateViews(_ paginationView: PaginationView)

    /// Returns the number of positions (as in `Publication.positionList`) in the page view at given index.
    func paginationView(_ paginationView: PaginationView, positionCountAtIndex index: Int) -> Int
}

class PaginationView: UIView, Loggable {
    weak var delegate: PaginationViewDelegate?

    /// Total number of page views to be paginated.
    internal var pageCount: Int = 0

    /// Index of the page currently being displayed.
    internal var currentIndex: Int = 0

    /// Direction for the reading progression.
    internal var readingProgression: ReadingProgression = .ltr

    /// Pre-loaded page views, indexed by their position.
    internal var loadedViews: [Int: UIView & PageView] = [:]

    /// Number of positions (as in `Publication.positionList`) to preload before and after the
    /// current page.
    internal let preloadPreviousPositionCount: Int
    internal let preloadNextPositionCount: Int

    /// Queue of page index to be loaded next.
    internal var loadingIndexQueue: [(index: Int, location: PageLocation)] = []

    /// Returns whether the page views are loaded.
    var isEmpty: Bool {
        loadedViews.isEmpty
    }

    /// Return the currently presented page view from the Views array.
    var currentView: (UIView & PageView)? {
        loadedViews[currentIndex]
    }

    /// Loaded page views in reading order.
    internal var orderedViews: [UIView & PageView] {
        var orderedViews = loadedViews
            .sorted { $0.key < $1.key }
            .map(\.value)

        if readingProgression == .rtl {
            orderedViews.reverse()
        }

        return orderedViews
    }

    internal let scrollView = UIScrollView()

    init(frame: CGRect, preloadPreviousPositionCount: Int, preloadNextPositionCount: Int) {
        self.preloadPreviousPositionCount = preloadPreviousPositionCount
        self.preloadNextPositionCount = preloadNextPositionCount

        super.init(frame: frame)

        scrollView.frame = bounds
        scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrollView.bounces = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)

        // Adds an empty view before the scroll view to have a consistent behavior on all iOS
        // versions, regarding to the content inset adjustements. Even if
        // `automaticallyAdjustsScrollViewInsets` is not set to false on the navigator's parent
        // view controller, the scroll view insets won't be adjusted if the scroll view is not the
        // first child in the subviews hierarchy.
        insertSubview(UIView(frame: .zero), at: 0)
        // Prevents the content from jumping down when the status bar is toggled
        scrollView.contentInsetAdjustmentBehavior = .never
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Returns the x offset to the page view with given index in the scroll view.
    internal func xOffsetForIndex(_ index: Int) -> CGFloat {
        return scrollView.contentOffset.x
    }
    
    internal func yOffsetForIndex(_ index: Int) -> CGFloat {
        scrollView.contentOffset.y
    }

    /// Reloads the pagination with the given total number of pages and current index.
    ///
    /// - Parameters:
    ///   - index: Index of the page to be displayed after reloading the pagination.
    ///   - location: Location to be displayed in the page.
    ///   - pageCount: Total number of pages in the pagination view.
    ///   - readingProgression: Direction of reading progression.
    ///   - completion: Closure called when the location is loaded.
    func reloadAtIndex(_ index: Int, location: PageLocation, pageCount: Int, readingProgression: ReadingProgression, completion: @escaping () -> Void) {
        precondition(pageCount >= 1)
        precondition(0 ..< pageCount ~= index)

        self.pageCount = pageCount
        self.readingProgression = readingProgression

        for (_, view) in loadedViews {
            view.removeFromSuperview()
        }
        loadedViews.removeAll()
        loadingIndexQueue.removeAll()

        setCurrentIndex(index, location: location, completion: completion)
    }

    /// Updates the current and pre-loaded views.
    internal func setCurrentIndex(_ index: Int, location: PageLocation? = nil, completion: @escaping () -> Void = {}) {
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

        for (i, view) in loadedViews {
            // Flushes the views that are not needed anymore.
            guard firstIndex ... lastIndex ~= i else {
                view.removeFromSuperview()
                loadedViews.removeValue(forKey: i)
                continue
            }
        }

        loadNextPage { [weak self] in
            if let self = self {
                self.delegate?.paginationViewDidUpdateViews(self)
                completion()
            }
        }
    }

    internal func loadNextPage(completion: @escaping () -> Void) {
        guard let (index, location) = loadingIndexQueue.popFirst() else {
            completion()
            return
        }

        if
            loadedViews[index] == nil,
            let view = delegate?.paginationView(self, pageViewAtIndex: index)
        {
            loadedViews[index] = view
            scrollView.addSubview(view)
            setNeedsLayout()
        }

        guard let view = loadedViews[index] else {
            completion()
            return
        }

        view.go(to: location) {
            self.loadNextPage(completion: completion)
        }
    }

    /// Queue views to be loaded until reaching the given number of pre-loaded positions.
    ///
    /// - Parameters:
    ///   - positionCount: Number of positions to pre-load before stopping.
    ///   - sourceIndex: Starting page index from which to pre-load the views.
    ///   - direction: The direction in which to load the views from the sourceIndex.
    /// - Returns: The last page index to be loaded after reaching the requested number of positions.
    internal func scheduleLoadPages(from sourceIndex: Int, upToPositionCount positionCount: Int, direction: PageIndexDirection, location: PageLocation) -> Int {
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
    internal func scheduleLoadPage(at index: Int, location: PageLocation) -> Bool {
        guard 0 ..< pageCount ~= index else {
            return false
        }

        loadingIndexQueue.removeAll { $0.index == index }
        loadingIndexQueue.append((index: index, location: location))
        return true
    }

    internal enum PageIndexDirection: Int {
        case forward = 1
        case backward = -1
    }

    // MARK: - Navigation

    /// Go to the page view with given index.
    ///
    /// - Parameters:
    ///   - index: The index to move to.
    ///   - location: The location to move the future current page view to.
    /// - Returns: Whether the move is possible.
    func goToIndex(_ index: Int, location: PageLocation, animated: Bool = false, completion: @escaping () -> Void) -> Bool {
        fatalError("Subclasses must implement this!")
    }
}
