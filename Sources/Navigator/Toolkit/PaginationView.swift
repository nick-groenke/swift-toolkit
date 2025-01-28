//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
    func go(to location: PageLocation) async
    func isLoaded() -> Bool
    func getContentHeightNow() -> Double?
//    func getContentHeight() async -> Double?
}

protocol PaginationViewDelegate: AnyObject {
    /// Creates the page view for the page at given index.
    func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)?

    /// Called when the page views were updated.
    func paginationViewDidUpdateViews(_ paginationView: PaginationView)

    /// Returns the number of positions (as in `Publication.positionList`) in the page view at given index.
    func paginationView(_ paginationView: PaginationView, positionCountAtIndex index: Int) -> Int
    
    func getNumberOfSpineItems() -> Int
}

final class PaginationView: UIView, Loggable {
    weak var delegate: PaginationViewDelegate?
    private let tableView = UITableView()
    var loadedViews: [Int : any UIView & PageView] = [:]
    var isScrollEnabled: Bool
    
    
    init(frame: CGRect, preloadPreviousPositionCount: Int, preloadNextPositionCount: Int, isScrollEnabled: Bool) {
        self.isScrollEnabled = isScrollEnabled
        super.init(frame: frame)

        tableView.frame = bounds
        tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        tableView.bounces = false
        tableView.showsHorizontalScrollIndicator = false
        addSubview(tableView)

        // Prevents the content from jumping down when the status bar is toggled
        tableView.contentInsetAdjustmentBehavior = .never
        
        tableView.isPagingEnabled = false
        tableView.delegate = self
        tableView.dataSource = self
//        tableView.prefetchDataSource = self
        tableView.backgroundColor = .brown
        
        tableView.register(PageViewTableCell.self, forCellReuseIdentifier: "PageViewTableCell")
        
        NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleWebViewDidLoad(_:)),
                    name: .webViewDidLoad,
                    object: nil
                )
    }
    
    @objc private func handleWebViewDidLoad(_ notification: Notification) {
        print("handleWebViewDidLoad called in PaginationView")
            guard let pageView = notification.object as? (UIView & PageView) else {
                print("unexpected object type in handleWebViewDidLoad")
                return
            }
            
            // Find the index of this pageView in the loadedViews dict
            guard let (index, _) = loadedViews.first(where: { $0.value === pageView }) else {
                print("Couldn't find the pageView in the loadedViews dict")
                return
            }
        
        print(" reloading row \(index) in tableView")
            
//            // Now we can update that row's height
            let indexPath = IndexPath(row: index, section: 0)
//            
//            // Option 1: Reload just this row
            tableView.reloadRows(at: [indexPath], with: .none)

            // Option 2: Use beginUpdates/endUpdates
//        tableView.beginUpdates()
//        tableView.endUpdates()
        }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var currentIndex: Int = 0
    
    var currentView: (UIView & PageView)? {
//        for (_, v) in loadedViews {
//            if v.frame.contains(scrollView.contentOffset) {
//                return v
//            }
//        }
        return nil
    }
    
    private func getView(for index: Int) -> (UIView & PageView)? {
        if let existing = loadedViews[index] {
//            print("return existing view for index \(index)")
            return existing
        }
        
        print("loading from scratch for index \(index)")
        
        guard let newView = delegate?.paginationView(self, pageViewAtIndex: index) else { return nil }
        newView.frame.origin = CGPoint(x: -5000, y: 0)
        newView.frame.size = frame.size
        loadedViews[index] = newView
        
        return newView
    }
    
    func goToIndex(_ index: Int, location: PageLocation, options: NavigatorGoOptions) async -> Bool {
        log(.info, "GO TO INDEX \(index) \(location)")
        await reloadAtIndex(index, location: location, pageCount: 0, readingProgression: .ltr)
        return true
    }
    
    
    func reloadAtIndex(_ index: Int, location: PageLocation, pageCount: Int, readingProgression: ReadingProgression) async {
        log(.info, "RELOAD AT INDEX \(index) \(location)")
    }
    
}

extension PaginationView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let pageView = getView(for: indexPath.row),
           pageView.isLoaded(),
           let contentHeight = pageView.getContentHeightNow() {
//            print("content height for row \(indexPath.row) is \(contentHeight)")
            return contentHeight
        }
        
//        print("returning default height 555 for row \(indexPath.row)")
        return 555
    }
}

extension PaginationView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return delegate?.getNumberOfSpineItems() ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let view = getView(for: indexPath.row)!
        view.frame.origin.x = -2000
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PageViewTableCell", for: indexPath) as! PageViewTableCell
    
        cell.set(newPageView: view, newIndex: indexPath.row)
        
        cell.setDebugText("Row: \(indexPath.row)")
        
        return cell
    }
    
    
}

extension PaginationView: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            print("prefetching row \(indexPath.row)")
            getView(for: indexPath.row)
        }
    }
}

class BufferTableCell: UITableViewCell {
    
}


class PageViewTableCell: UITableViewCell {
    // Debug label for overlay
    private let debugLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.textColor = .white
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.layer.zPosition = 9999
        return label
    }()
    
    
    var pageView: (UIView & PageView)?
    var usedBefore = false
    var index = -1
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Add the label on top of everything else
        contentView.addSubview(debugLabel)
        
        // Set up constraints (for example, center it or pin to some corner)
        NSLayoutConstraint.activate([
            debugLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            debugLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
            // Alternatively, you can center or stretch it as needed:
        ])
        debugLabel.layer.zPosition = 9999
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.bringSubviewToFront(debugLabel)
        print("Cell at index \(index) contentView has \(subviews.count) subviews: \(subviews)")
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setDebugText(_ text: String) {
        debugLabel.text = text
        // Ensure it's on top of other subviews (if needed)
        contentView.bringSubviewToFront(debugLabel)
        debugLabel.layer.zPosition = 9999
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.pageView?.removeFromSuperview()
        self.pageView = nil
    }
    
    func set(newPageView: (UIView & PageView)?, newIndex: Int) {
        precondition(self.pageView == nil, "self.pageView must be nil. If it's not, then maybe prepareForReuse wasn't called or has a bug.")
        precondition(newPageView != nil, "newPageView must not be nil.")
        guard let newPageView else { return }
        
        self.index = newIndex
        self.pageView = newPageView
        
        addSubview(newPageView)

        newPageView.frame.origin = .zero
        
        
        
        
        layer.borderWidth = 1
        layer.borderColor = UIColor.green.cgColor
        backgroundColor = .yellow
        newPageView.frame.size.width = bounds.width - 50
        frame.size = newPageView.frame.size
    }
}


extension Notification.Name {
    static let webViewDidLoad = Notification.Name("WebViewDidLoadNotification")
}

