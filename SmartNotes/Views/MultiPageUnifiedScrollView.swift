//
//  MultiPageUnifiedScrollView.swift
//  SmartNotes
//
//  Created by You on 3/5/25.
//  Updated on 3/6/25 to apply a single note-wide template to each page
//

import SwiftUI
import PencilKit
import ObjectiveC

// Add the missing PageViewModel class
class PageViewModel {
    var horizontalSizeClass: UserInterfaceSizeClass?
    var verticalSizeClass: UserInterfaceSizeClass?
    
    init(_ horizontalSizeClass: UserInterfaceSizeClass?, _ verticalSizeClass: UserInterfaceSizeClass?) {
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
    }
}

// A custom scroll view subclass that can store additional context
class MultiPageScrollView: UIScrollView {
    // These properties store page data so the view can update itself
    var pages: [Page] = []
    var pageViewModels: [UUID: PageViewModel] = [:]
    var context: MultiPageUnifiedScrollView.Coordinator?
    
    // Called by the coordinator to draw pages on demand
    func drawPages() {
        context?.layoutPages()
    }
}

struct MultiPageUnifiedScrollView: UIViewRepresentable {
    // Track which updates are coming from where
    private static var updateCounter = 0
    
    @Binding var pages: [Page]
    @Binding var template: CanvasTemplate
    
    // Access app settings
    @EnvironmentObject var appSettings: AppSettingsModel
    
    // Use the scaled page size from GlobalSettings
    var pageSize: CGSize {
        return GlobalSettings.scaledPageSize
    }
    
    // Increased spacing between pages for better visual separation
    let pageSpacing: CGFloat = 12 * GlobalSettings.resolutionScaleFactor  // Increased from 2 to 12
    
    class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate, PKToolPickerObserver {
        var parent: MultiPageUnifiedScrollView
        var scrollView: UIScrollView?
        var containerView: UIView?
        
        // Keep references to each PKCanvasView by page ID
        var canvasViews: [UUID: PKCanvasView] = [:]
        
        // Keep track of page view models by page ID
        var pageViewModels: [UUID: PageViewModel] = [:]
        
        // Avoid repeated triggers during initial load
        var isInitialLoad = true
        
        // Track whether pages are being laid out
        var isLayoutingPages = false
        
        // Tool properties
        var selectedTool: PKInkingTool.InkType = .pen
        var selectedColor: UIColor = .black
        var lineWidth: CGFloat = 2.0 * GlobalSettings.resolutionScaleFactor
        
        // Store initial size for later comparison
        var previousSize: CGSize?
        
        // Add tracking for the currently visible page
        var currentlyVisiblePageIndex: Int = 0
        
        // Track whether page navigation is locked to selection
        var isPageNavigationLockedToSelection: Bool = true
        
        init(_ parent: MultiPageUnifiedScrollView) {
            self.parent = parent
            super.init()
            
            // Register for page navigation notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollToSelectedPage(_:)),
                name: NSNotification.Name("ScrollToPage"),
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return containerView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Use the simpler centering approach
            centerContainer(scrollView: scrollView)
            
            // Still update rendering quality for different zoom levels
            updateCanvasRenderingForZoomScale(scrollView.zoomScale)
        }
        
        // Simplified centering function from the older version
        func centerContainer(scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let offsetX = max((scrollView.bounds.width - container.frame.width * scrollView.zoomScale) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - container.frame.height * scrollView.zoomScale) * 0.5, 0)
            
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // Simple flag for reducing quality during scrolling
            for (_, canvasView) in canvasViews {
                // Lower quality during scrolling
                if #available(iOS 16.0, *) {
                    canvasView.drawingPolicy = .pencilOnly
                } else {
                    canvasView.allowsFingerDrawing = false
                }
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // If not decelerating, restore quality immediately
            if !decelerate {
                for (_, canvasView) in canvasViews {
                    // Restore normal quality
                    let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
                    if #available(iOS 16.0, *) {
                        canvasView.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
                    } else {
                        canvasView.allowsFingerDrawing = !disableFingerDrawing
                    }
                }
                
                // Re-center content
                centerContainer(scrollView: scrollView)
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // Restore quality after scrolling stops
            for (_, canvasView) in canvasViews {
                // Restore normal quality
                let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
                if #available(iOS 16.0, *) {
                    canvasView.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
                } else {
                    canvasView.allowsFingerDrawing = !disableFingerDrawing
                }
            }
            
            // Re-center when done
            centerContainer(scrollView: scrollView)
        }
        
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // Lower quality during zooming
            for (_, canvasView) in canvasViews {
                // Lower quality during zooming
                if #available(iOS 16.0, *) {
                    canvasView.drawingPolicy = .pencilOnly
                } else {
                    canvasView.allowsFingerDrawing = false
                }
            }
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            guard let appSettings = getAppSettings() else { return }
            
            // Restore quality after zooming stops
            if appSettings.optimizeDuringInteraction {
                for (_, canvasView) in canvasViews {
                    // Restore normal quality
                    let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
                    if #available(iOS 16.0, *) {
                        canvasView.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
                    } else {
                        canvasView.allowsFingerDrawing = !disableFingerDrawing
                    }
                }
            }
            
            // Log the final zoom scale for debugging
            if GlobalSettings.debugModeEnabled {
                print("🔎 Final zoom scale: \(scale)")
            }
            
            // Re-center when zooming completes
            centerContainer(scrollView: scrollView)
        }
        
        func scrollViewDidLayoutSubviews(_ scrollView: UIScrollView) {
            // After layout changes (like rotation), re-center content
            centerContainer(scrollView: scrollView)
        }
        
        // MARK: - PKCanvasViewDelegate
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Don't update during initial loading
            if isInitialLoad {
                return
            }
            
            // Find which page this canvas belongs to
            if let pageID = canvasViews.first(where: { $0.value == canvasView })?.key,
               let pageIndex = parent.pages.firstIndex(where: { $0.id == pageID }) {
                
                // Get drawing data
                let drawing = canvasView.drawing
                let drawingData = try? drawing.dataRepresentation()
                
                if let drawingData = drawingData {
                    // Update the page's drawing data
                    parent.pages[pageIndex].drawingData = drawingData
                    
                    // Invalidate the thumbnail for this page
                    PageThumbnailGenerator.clearCache(for: pageID)
                    
                    // Check if we need to add a page after updating the model
                    checkForNextPageNeeded(pageIndex: pageIndex, canvasView: canvasView)
                    
                    // Post notification that drawing has changed
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PageDrawingChanged"),
                        object: pageID
                    )
                    
                    // Also send a notification that can be used to trigger live updates
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("LiveDrawingUpdate"),
                            object: pageID
                        )
                    }
                }
            }
        }
        
        func checkForNextPageNeeded(pageIndex: Int, canvasView: PKCanvasView) {
            // We want to add a new page if:
            // 1. This is the last page (pageIndex == parent.pages.count - 1)
            // 2. There are strokes on this page (canvasView.drawing.strokes.count > 0)
            
            if pageIndex == (parent.pages.count - 1) && !canvasView.drawing.strokes.isEmpty {
                // This is the last page and it has content
                let hasLastPageAlready = parent.pages.count > pageIndex + 1
                
                if !hasLastPageAlready {
                    print("📝 Last page has content, adding a new blank page")
                    addPage()
                }
            }
        }
        
        func addPage() {
            print("📄 Creating new page #\(parent.pages.count + 1)")
            let newPage = Page(
                drawingData: Data(),
                template: nil,
                pageNumber: parent.pages.count + 1
            )
            
            DispatchQueue.main.async {
                // Add the new page to the model
                self.parent.pages.append(newPage)
                
                // Force layout to update with the new page
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.layoutPages()
                }
            }
        }
        
        // MARK: - Page Layout & Setup
        
        // Simplified layout method with clearer positioning logic
        func layoutPages() {
            // Prevent re-entrancy
            if isLayoutingPages {
                return
            }
            
            isLayoutingPages = true
            
            guard let container = containerView,
                  let scrollView = scrollView else {
                isLayoutingPages = false
                return
            }
            
            print("📄 Beginning layout of \(parent.pages.count) pages with template \(parent.template.type.rawValue)")
            
            // Check for empty pages array
            if parent.pages.isEmpty {
                print("⚠️ Warning: layoutPages() called with empty pages array.")
                isLayoutingPages = false
                return
            }
            
            // Remove subviews for any pages that no longer exist
            for subview in container.subviews {
                if let cv = subview as? PKCanvasView {
                    if let tagID = cv.tagID, !parent.pages.contains(where: { $0.id == tagID }) {
                        cv.removeFromSuperview()
                        canvasViews.removeValue(forKey: tagID)
                    }
                }
            }
            
            // Add a defensive safety check to reset currentlyVisiblePageIndex if invalid
            if currentlyVisiblePageIndex >= parent.pages.count {
                currentlyVisiblePageIndex = max(0, min(parent.pages.count - 1, 0))
                print("⚠️ Reset currentlyVisiblePageIndex to \(currentlyVisiblePageIndex) because it was out of range")
            }
            
            // Ensure each page has a PKCanvasView
            var newViewsCreated = 0
            var existingViewsUpdated = 0
            
            for (index, page) in parent.pages.enumerated() {
                let cv: PKCanvasView
                
                if let existing = canvasViews[page.id] {
                    cv = existing
                    existingViewsUpdated += 1
                } else {
                    cv = PKCanvasView()
                    cv.tagID = page.id
                    cv.delegate = self
                    
                    // Load existing drawing
                    cv.drawing = PKDrawing.fromData(page.drawingData)
                    
                    // Configure high resolution canvas
                    configureCanvas(cv)
                    
                    // Save reference
                    canvasViews[page.id] = cv
                    container.addSubview(cv)
                    newViewsCreated += 1
                }
                
                // Position the canvas vertically
                let yPos = CGFloat(index) * (parent.pageSize.height + parent.pageSpacing)
                cv.frame = CGRect(
                    x: 0,
                    y: yPos,
                    width: parent.pageSize.width,
                    height: parent.pageSize.height
                )
                
                // Enhance shadow for better contrast between pages and background
                cv.layer.shadowColor = UIColor.black.cgColor
                cv.layer.shadowOpacity = 0.3  // Increased from 0.15 to 0.3
                cv.layer.shadowOffset = CGSize(width: 0, height: 4)  // Increased from 2 to 4
                cv.layer.shadowRadius = 50  // Increased from 6 to 10
                cv.layer.cornerRadius = 40
                cv.backgroundColor = UIColor.white
                
                // Add page number to top right corner
                let pageNumberLabel = UILabel()
                pageNumberLabel.text = "\(index + 1)"
                pageNumberLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                pageNumberLabel.textColor = UIColor.darkGray
                pageNumberLabel.backgroundColor = UIColor(white: 0.95, alpha: 0.8)
                pageNumberLabel.textAlignment = .center
                pageNumberLabel.layer.cornerRadius = 12
                pageNumberLabel.layer.masksToBounds = true
                pageNumberLabel.sizeToFit()
                
                // Set fixed size for consistent appearance
                let labelSize = CGSize(width: max(pageNumberLabel.bounds.width + 12, 24), height: 24)
                pageNumberLabel.frame = CGRect(
                    x: parent.pageSize.width - labelSize.width - 12,
                    y: 12,
                    width: labelSize.width,
                    height: labelSize.height
                )
                
                // Remove any existing page number labels before adding a new one
                for subview in cv.subviews {
                    if subview.tag == 999 {
                        subview.removeFromSuperview()
                    }
                }
                
                pageNumberLabel.tag = 999
                cv.addSubview(pageNumberLabel)
                
                // Apply the template lines/dots
                applyTemplate(to: cv)
            }
            
            print("📄 Layout complete: created \(newViewsCreated) new canvas views, updated \(existingViewsUpdated) existing views")
            
            // Update container frame
            let totalHeight = max(1, CGFloat(parent.pages.count)) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            
            // Simpler container setup, matching old version
            container.frame = CGRect(
                x: 0, 
                y: 0, 
                width: parent.pageSize.width,
                height: totalHeight
            )
            
            // Update scroll view content size to match the container size exactly
            scrollView.contentSize = container.frame.size
            
            // Use simpler centering approach
            centerContainer(scrollView: scrollView)
            
            // Make the first canvas the first responder
            if let firstCanvas = canvasViews.first?.value {
                DispatchQueue.main.async {
                    firstCanvas.becomeFirstResponder()
                }
            }
            
            // Reset layout flag
            isLayoutingPages = false
        }
        
        /// Configure a canvas for optimal display
        func configureCanvas(_ canvasView: PKCanvasView) {
            // Apply finger drawing policy based on settings
            let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
            if #available(iOS 16.0, *) {
                canvasView.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
            } else {
                canvasView.allowsFingerDrawing = !disableFingerDrawing
            }
            
            // Ensure no content insets on the canvas itself
            canvasView.contentInset = .zero
            
            // Ensure we're set as the delegate to get tool notifications
            canvasView.delegate = self
            
            // We don't need to add an observer - we'll rely on delegate methods instead
        }
        
        /// Apply the template to the canvas
        func applyTemplate(to canvasView: PKCanvasView) {
            // First remove any existing template
            if let sublayers = canvasView.layer.sublayers {
                for layer in sublayers where layer.name == "TemplateLayer" {
                    layer.removeFromSuperlayer()
                }
            }
            
            for subview in canvasView.subviews where subview.tag == 888 {
                subview.removeFromSuperview()
            }
            
            // Apply the template
            TemplateRenderer.applyTemplateToCanvas(
                canvasView,
                template: parent.template,
                pageSize: parent.pageSize,
                numberOfPages: 1,
                pageSpacing: 0
            )
        }
        
        // MARK: - Tool Management
        
        /// Set a custom tool on all canvases
        func setCustomTool(type: PKInkingTool.InkType, color: UIColor, width: CGFloat) {
            let inkingTool = PKInkingTool(type, color: color, width: width)
            
            for (_, canvasView) in canvasViews {
                canvasView.tool = inkingTool
            }
        }
        
        /// Get the currently active canvas
        func getActiveCanvasView() -> PKCanvasView? {
            for (_, canvasView) in canvasViews {
                if canvasView.isFirstResponder {
                    return canvasView
                }
            }
            return canvasViews.first?.value
        }
        
        // MARK: - Rendering Quality
        
        /// Update canvas rendering quality based on zoom scale - simpler version
        func updateCanvasRenderingForZoomScale(_ scale: CGFloat) {
            // We can adjust quality based on zoom if needed in the future
            // In this simpler implementation, we don't need complex adjustments
            if GlobalSettings.debugModeEnabled {
                print("📏 Zoom scale: \(scale)")
            }
        }
        
        /// Get app settings
        func getAppSettings() -> AppSettingsModel? {
            return parent.appSettings
        }
        
        // Add a method to scroll to a specific page
        @objc func scrollToSelectedPage(_ notification: Notification) {
            // Add early safety check for initial loading state
            guard !isInitialLoad, !isLayoutingPages else {
                print("⚠️ Warning: Ignoring page selection during initial load or layout")
                return
            }
        
            guard let pageIndex = notification.object as? Int,
                  pageIndex >= 0 && pageIndex < parent.pages.count,  // Add range validation
                  let scrollView = scrollView,
                  let container = containerView,
                  parent.pages.count > 0,  // Ensure we have pages
                  scrollView.contentSize.height > 0  // Ensure content size is valid
            else {
                print("⚠️ Warning: Invalid state for page scrolling. Pages: \(parent.pages.count), Index: \(notification.object as? Int ?? -1)")
                return
            }
            
            // Calculate the position to scroll to
            var offsetY: CGFloat = 0
            for i in 0..<pageIndex {
                // Add the height of each preceding canvas plus spacing
                if i < parent.pages.count {
                    offsetY += parent.pageSize.height + parent.pageSpacing
                }
            }
            
            // Critical fix: Adjust for current zoom scale
            // When zoomed out, we need to reduce the offset proportionally
            offsetY = offsetY * scrollView.zoomScale
            
            // Ensure we don't scroll beyond content bounds
            let maxPossibleOffset = scrollView.contentSize.height * scrollView.zoomScale - scrollView.bounds.height
            offsetY = min(offsetY, max(0, maxPossibleOffset))
            
            print("📏 Scrolling to page \(pageIndex+1): offsetY = \(offsetY), zoom = \(scrollView.zoomScale), resolution factor = \(GlobalSettings.resolutionScaleFactor)")
            
            // Animate scrolling to the selected page with slower animation
            UIView.animate(withDuration: 0.75, 
                      delay: 0,
                      options: [.curveEaseInOut],
                      animations: {
                scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
            }, completion: { _ in
                // After scrolling completes, deselect the page
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Post notification to deactivate page selection
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PageSelectionDeactivated"),
                        object: nil
                    )
                    print("📜 Scrolled to page \(pageIndex+1) - automatically deselecting")
                }
            })
        }
        
        // Add a method to determine which page is currently visible
        func determineVisiblePage() {
            // Add safety check to prevent crash on empty pages
            guard let scrollView = scrollView, 
                  parent.pages.count > 0, 
                  !isInitialLoad, 
                  !isLayoutingPages else { return }
            
            // Get the scroll view's current vertical position
            let offsetY = scrollView.contentOffset.y
            
            // Account for zoom scale when calculating page position
            let effectiveOffsetY = offsetY / scrollView.zoomScale
            
            let pageHeight = parent.pageSize.height + parent.pageSpacing
            
            // Calculate the visible page index based on the scroll position, adjusted for zoom
            let visiblePageIndex = min(
                max(Int(round(effectiveOffsetY / pageHeight)), 0),
                parent.pages.count - 1
            )
            
            // Add safety check before accessing arrays
            guard visiblePageIndex >= 0 && visiblePageIndex < parent.pages.count else {
                print("⚠️ Warning: Calculated visible page index \(visiblePageIndex) is out of range (pages count: \(parent.pages.count))")
                return
            }
            
            // Only notify if the visible page has changed
            if visiblePageIndex != currentlyVisiblePageIndex {
                currentlyVisiblePageIndex = visiblePageIndex
                
                // Print the current visible page
                print("📄 Visible page changed to: \(visiblePageIndex + 1) of \(parent.pages.count)")
                
                // Notify that the visible page has changed - this only updates the highlight
                // in the navigator but doesn't trigger automatic scrolling
                NotificationCenter.default.post(
                    name: NSNotification.Name("PageSelected"),
                    object: visiblePageIndex
                )
            }
        }
        
        // Update scrollViewDidScroll to determine the visible page
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Always determine which page is visible
            determineVisiblePage()
        }
        
        // Add this method to the Coordinator class
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            // Find which page this canvas belongs to
            if let pageID = canvasViews.first(where: { $0.value == canvasView })?.key {
                // Post notification that drawing has started
                NotificationCenter.default.post(
                    name: NSNotification.Name("DrawingStarted"),
                    object: pageID
                )
            }
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            // Find which page this canvas belongs to
            if let pageID = canvasViews.first(where: { $0.value == canvasView })?.key {
                // Force an immediate thumbnail update when drawing ends
                NotificationCenter.default.post(
                    name: NSNotification.Name("PageDrawingChanged"),
                    object: pageID
                )
            }
        }
        
        // MARK: - PKToolPickerObserver
        func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
            // Implementation required by protocol
        }
        
        func toolPickerIsRulerActiveDidChange(_ toolPicker: PKToolPicker) {
            // Implementation required by protocol
        }
        
        func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
            // Implementation required by protocol
        }
        
        func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
            // Implementation required by protocol
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        MultiPageUnifiedScrollView.updateCounter += 1
        
        let scrollView = MultiPageScrollView()
        scrollView.delegate = context.coordinator
        
        // Simple zoom constraints matching the original code
        scrollView.minimumZoomScale = 0.3
        scrollView.maximumZoomScale = 3.0
        
        // Basic scrolling setup
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.indicatorStyle = .black
        scrollView.backgroundColor = UIColor.systemGray6  // Lighter background color for better contrast
        
        // Create container view for all canvases
        let container = UIView()
        container.backgroundColor = UIColor.systemGray6  // Matching background
        scrollView.addSubview(container)
        
        // Save references
        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = container
        
        // If pages is empty, create at least one page
        if pages.isEmpty {
            let newPage = Page(
                drawingData: Data(),
                template: nil,
                pageNumber: 1
            )
            // Use immediate assignment rather than async to ensure it's available during initialization
            self.pages = [newPage]
            print("📄 Created initial page for new note with ID: \(newPage.id)")
        }
        
        // Set initial zoom scale to 1.0
        scrollView.zoomScale = 1.0
        
        // Store initial size for later comparison
        context.coordinator.previousSize = scrollView.bounds.size
        
        // Listen for template refresh notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshTemplate"),
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.pages.isEmpty { return }
                
                if let container = context.coordinator.containerView {
                    // Force refresh by clearing and rebuilding canvas views
                    for subview in container.subviews {
                        subview.removeFromSuperview()
                    }
                    context.coordinator.canvasViews.removeAll()
                    
                    // Force full redraw
                    context.coordinator.layoutPages()
                }
            }
        }
        
        // Listen for sidebar visibility changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SidebarVisibilityChanged"),
            object: nil, 
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                context.coordinator.centerContainer(scrollView: scrollView)
            }
        }
        
        // Listen for page selection deactivation
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PageSelectionDeactivated"),
            object: nil,
            queue: .main
        ) { _ in
            // Unlock page navigation from selection
            context.coordinator.isPageNavigationLockedToSelection = false
            print("📜 Page selection deactivated - free scrolling enabled")
        }
        
        // Perform initial layout with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.layoutPages()
            context.coordinator.isInitialLoad = false
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        MultiPageUnifiedScrollView.updateCounter += 1
        
        // Skip updates during initial load
        if context.coordinator.isInitialLoad {
            return
        }
        
        // Skip update if pages array is empty
        if pages.isEmpty {
            return
        }
        
        // Pass our scroll view to the coordinator
        context.coordinator.scrollView = scrollView
        
        // Check if size has changed 
        if let multiPageScrollView = scrollView as? MultiPageScrollView {
            // Set context for the scroll view
            multiPageScrollView.context = context.coordinator
            
            // Update pages reference
            multiPageScrollView.pages = pages
            multiPageScrollView.pageViewModels = context.coordinator.pageViewModels
            
            // Check for size changes
            let newSize = scrollView.bounds.size
            if context.coordinator.previousSize != newSize && !newSize.width.isZero && !newSize.height.isZero {
                context.coordinator.previousSize = newSize
                
                // Simply call centerContainer instead of the more complex logic
                context.coordinator.centerContainer(scrollView: scrollView)
            }
        }
        
        // Check if we need to do a full layout update
        let existingViewCount = context.coordinator.canvasViews.count
        let pagesWithoutViews = pages.filter { !context.coordinator.canvasViews.keys.contains($0.id) }
        
        if pagesWithoutViews.isEmpty && existingViewCount == pages.count {
            // We have all the views we need, just update templates if needed
        } else {
            // Do a full layout refresh
            context.coordinator.layoutPages()
        }
        
        // Post coordinator ready notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("CoordinatorReady"),
                object: context.coordinator
            )
        }
    }
}

// A helper to store the page ID on each PKCanvasView
fileprivate extension PKCanvasView {
    private struct AssociatedKeys {
        static var tagIDKey = "tagIDKey"
    }
    
    var tagID: UUID? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.tagIDKey) as? UUID }
        set { objc_setAssociatedObject(self, &AssociatedKeys.tagIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
