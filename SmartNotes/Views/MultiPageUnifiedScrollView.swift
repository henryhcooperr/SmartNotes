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
        return ResolutionManager.shared.scaledPageSize
    }
    
    // Increased spacing between pages for better visual separation
    let pageSpacing: CGFloat = 12 * ResolutionManager.shared.resolutionScaleFactor  // Increased from 2 to 12
    
    /// Flag to track if a layout operation is in progress
    @State private var isPerformingLayout = false
    
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
        var lineWidth: CGFloat = 2.0 * ResolutionManager.shared.resolutionScaleFactor
        
        // Store initial size for later comparison
        var previousSize: CGSize?
        
        // Add tracking for the currently visible page
        var currentlyVisiblePageIndex: Int = 0
        
        // Track whether page navigation is locked to selection
        var isPageNavigationLockedToSelection: Bool = true
        
        // Add a coordinate grid to the view
        @objc var gridView: UIView?
        
        init(_ parent: MultiPageUnifiedScrollView) {
            self.parent = parent
            super.init()
            
            // Register for page navigation notifications
            subscriptionManager.subscribe(PageEvents.ScrollToPage.self) { [weak self] (event: PageEvents.ScrollToPage) in
                self?.scrollToSelectedPage(event.pageIndex)
            }
            
            // Register for page selection by user
            subscriptionManager.subscribe(PageEvents.PageSelectedByUser.self) { [weak self] (event: PageEvents.PageSelectedByUser) in
                self?.scrollToSelectedPage(event.pageIndex)
            }
            
            // Register for page reordering notifications
            subscriptionManager.subscribe(PageEvents.PageReordering.self) { [weak self] (event: PageEvents.PageReordering) in
                self?.handlePageReordering(event)
            }
            
            // Register for tool change events from EventBus
            subscriptionManager.subscribe(ToolEvents.ToolChanged.self) { [weak self] (event: ToolEvents.ToolChanged) in
                self?.handleToolChangeEvent(event)
            }
            
            // Notify that the coordinator is ready
            EventBus.shared.publish(SystemEvents.CoordinatorReady(coordinator: self))
        }
        
        deinit {
            // Clean up subscriptions
            subscriptionManager.clearAll()
            
            // Unregister all canvases from CanvasManager
            for pageID in canvasViews.keys {
                CanvasManager.shared.unregisterCanvas(withID: pageID)
            }
        }
        
        // MARK: - Scroll to Selected Page
        @objc func scrollToSelectedPage(_ pageIndex: Int) {
            scrollToSelectedPage(PageEvents.ScrollToPage(pageIndex: pageIndex))
        }
        
        func scrollToSelectedPage(_ event: PageEvents.ScrollToPage) {
            guard !parent.isPerformingLayout, parent.pages.count > 0 else {
                print("⚠️ Warning: Ignoring page selection during initial load or layout")
                return
            }
            
            let pageIndex = event.pageIndex
            
            guard pageIndex >= 0 && pageIndex < parent.pages.count else {
                print("⚠️ Warning: Invalid state for page scrolling. Pages: \(parent.pages.count), Index: \(pageIndex)")
                return
            }
            
            // Get the scroll view
            guard let scrollView = containerView?.superview as? UIScrollView else {
                print("⚠️ Error: Could not find scroll view")
                return
            }
            
            // Get the containerView
            guard let container = containerView else {
                print("⚠️ Error: Could not find container view")
                return
            }
            
            print("🔍 Debug - Current visible page: \(currentlyVisiblePageIndex+1), Target: \(pageIndex+1), Zoom: \(scrollView.zoomScale)")
            
            // Use the CoordinateSpaceManager to calculate the correct offset for centering the page
            let coordManager = CoordinateSpaceManager.shared
            let newOffset = coordManager.scrollOffsetToCenter(pageIndex: pageIndex, scrollView: scrollView, container: container)
            
            // For debugging, show all the calculations
            let targetY = coordManager.pageYPositionInContainer(pageIndex: pageIndex)
            let pageCenterY = coordManager.pageCenterYInContainer(pageIndex: pageIndex)
            
            print("📏 Scroll calculation details:")
            print("📏 Target page index: \(pageIndex)")
            print("📏 Target Y position: \(targetY)")
            print("📏 Page center Y: \(pageCenterY)")
            print("📏 Current offset: \(scrollView.contentOffset.y)")
            print("📏 New offset: \(newOffset.y)")
            print("📏 Content size: \(scrollView.contentSize.height)")
            print("📏 Scroll view height: \(scrollView.bounds.height)")
            
            // Try to find the target view for additional debugging
            let targetPageView = container.subviews.first { view in
                return view.tag == pageIndex + 100
            }
            
            if let targetView = targetPageView {
                print("📏 Found target view: \(targetView) with frame \(targetView.frame)")
            } else {
                print("⚠️ Warning: Could not find target page view by tag \(pageIndex + 100)")
                // List all tags for debugging
                let tags = container.subviews.map { $0.tag }
                print("📋 Available tags: \(tags)")
            }
            
            // Use the UIScrollView's native animation instead of UIView animation
            scrollView.setContentOffset(newOffset, animated: true)
            
            // After a short delay to let the animation complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                // After scrolling, deactivate the selection to allow free scrolling
                self.isPageNavigationLockedToSelection = false
                EventBus.shared.publish(PageEvents.PageSelectionDeactivated())
                
                // Update the current visible page
                self.updateVisiblePageIndex()
                
                print("📜 Scrolled to page \(pageIndex+1) - automatically deselecting")
            }
        }
        
        // Simplified centering function from the older version
        func centerContainer(scrollView: UIScrollView) {
            guard let container = containerView else { return }
            
            // Use the CoordinateSpaceManager to calculate centering insets
            let coordManager = CoordinateSpaceManager.shared
            
            // Update zoom scale in the manager
            coordManager.updateZoomScale(scrollView.zoomScale)
            
            // Calculate the insets needed to center the container
            let insets = coordManager.calculateCenteringInsets(
                scrollView: scrollView,
                container: container
            )
            
            // Store previous position for logging
            let previousInset = scrollView.contentInset
            let previousFrame = container.frame
            
            // Apply the content insets to center the content
            scrollView.contentInset = insets
            
            // Log the centering changes
            print("📐 Container position: before=(\(Int(previousFrame.origin.x)), \(Int(previousFrame.origin.y))), inset before=(\(Int(previousInset.left)), \(Int(previousInset.top))), inset after=(\(Int(insets.left)), \(Int(insets.top))), zoom=\(scrollView.zoomScale)")
        }
        
        // MARK: - Handle Page Reordering
        @objc func handlePageReordering(_ notification: Notification) {
            if let fromIndex = notification.userInfo?["fromIndex"] as? Int,
               let toIndex = notification.userInfo?["toIndex"] as? Int {
                handlePageReordering(PageEvents.PageReordering(fromIndex: fromIndex, toIndex: toIndex))
            }
        }
        
        func handlePageReordering(_ event: PageEvents.PageReordering) {
            print("📄 Handling page reordering notification")
            
            // Request a layout update to reflect the new page order
            DispatchQueue.main.async {
                // After a short delay to allow the page array to update
                self.parent.requestLayoutUpdate()
                
                // Scroll to the moved page
                EventBus.shared.publish(PageEvents.ScrollToPage(pageIndex: event.toIndex))
            }
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
            
            // Update grid if it exists
            if let container = containerView, 
               container.subviews.contains(where: { $0.tag == 7777 }) {
                // Just refresh the grid with the new bounds
                addCoordinateGrid()
            }
            
            // Log container position for debugging
            if let container = containerView {
                print("📐 Container after zoom: origin=(\(container.frame.origin.x), \(container.frame.origin.y)), size=(\(container.frame.size.width), \(container.frame.size.height)), zoom=\(scrollView.zoomScale)")
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // Use CanvasManager to set temporary low resolution mode during scrolling
            for (id, canvasView) in canvasViews {
                CanvasManager.shared.setTemporaryLowResolutionMode(canvasView, enabled: true)
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                // If we're not going to decelerate, update the visible page now
                updateVisiblePageIndex()
                
                // Restore canvas quality
                guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
                for (id, canvasView) in canvasViews {
                    CanvasManager.shared.setTemporaryLowResolutionMode(canvasView, enabled: false)
                }
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            // Update the visible page after scrolling stops
            updateVisiblePageIndex()
            
            // Restore canvas quality
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            for (id, canvasView) in canvasViews {
                CanvasManager.shared.setTemporaryLowResolutionMode(canvasView, enabled: false)
            }
        }
        
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // Use CanvasManager to set temporary low resolution mode during zooming
            for (id, canvasView) in canvasViews {
                CanvasManager.shared.setTemporaryLowResolutionMode(canvasView, enabled: true)
            }
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            guard let appSettings = getAppSettings() else { return }
            
            // Restore canvas quality after zooming
            if appSettings.optimizeDuringInteraction {
                for (id, canvasView) in canvasViews {
                    CanvasManager.shared.setTemporaryLowResolutionMode(canvasView, enabled: false)
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
                    EventBus.shared.publish(DrawingEvents.PageDrawingChanged(pageId: pageID, drawingData: drawingData))
                    
                    // Also send a notification that can be used to trigger live updates
                    DispatchQueue.main.async {
                        EventBus.shared.publish(DrawingEvents.LiveDrawingUpdate(pageId: pageID))
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
        @objc func layoutPages() {
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
                        CanvasManager.shared.unregisterCanvas(withID: tagID)
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
                    // Use CanvasManager to create a new canvas
                    cv = CanvasManager.shared.createCanvas(withID: page.id, initialDrawing: page.drawingData)
                    cv.delegate = self
                    
                    // Set the tag ID for tracking
                    cv.tagID = page.id
                    
                    // Save reference
                    canvasViews[page.id] = cv
                    container.addSubview(cv)
                    newViewsCreated += 1
                }
                
                // Set the tag to match what's expected in scrollToSelectedPage
                cv.tag = index + 100
                
                // Position the canvas vertically using explicit index-based calculation
                let totalPageHeight = parent.pageSize.height + parent.pageSpacing
                let yPos = CGFloat(index) * totalPageHeight
                
                // Store old position for logging
                let oldYPos = cv.frame.origin.y
                
                // Update frame with new position
                cv.frame = CGRect(
                    x: 0,
                    y: yPos,
                    width: parent.pageSize.width,
                    height: parent.pageSize.height
                )
                
                // Log the positioning for debugging
                print("📄 Positioned page \(page.id.uuidString.prefix(8)) at index \(index), yPos=\(Int(yPos)) (moved from \(Int(oldYPos)))")
                
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
                applyTemplate(to: cv, template: parent.template)
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
            
            // After layout is complete (at the end of the method):
            if GlobalSettings.debugModeEnabled {
                // Add coordinate grid for debugging scaling issues
                if let container = containerView {
                    addCoordinateGrid()
                }
            }
            
            // Reset layout flag
            isLayoutingPages = false
        }
        
        /// Configure a canvas for optimal display
        func configureCanvas(_ canvasView: PKCanvasView) {
            // Use CanvasManager to configure the canvas
            CanvasManager.shared.configureCanvas(canvasView)
            
            // Set delegate to self to continue receiving drawing events
            canvasView.delegate = self
        }
        
        /// Apply the template to the canvas
        func applyTemplate(to canvasView: PKCanvasView, template: CanvasTemplate? = nil) {
            // Use the provided template if available, otherwise fall back to parent.template
            let templateToApply = template ?? parent.template
            
            // Debug output to track template application
            print("🖌️ Applying template: \(templateToApply.type.rawValue) to canvas view \(String(describing: canvasView.tagID?.uuidString.prefix(8) ?? "unknown"))")
            
            // Use CanvasManager to apply the template
            CanvasManager.shared.applyTemplate(to: canvasView, template: templateToApply, pageSize: parent.pageSize)
        }
        
        // MARK: - Tool Management
        
        /// Apply the current tool to a specific canvas
        func applyCurrentTool(to canvas: PKCanvasView) {
            // Handle eraser separately since it's not part of PKInkingTool.InkType
            if selectedTool == .pen && selectedColor.isEqual(UIColor.clear) {
                // Use PencilKit's eraser when tool is pen but color is clear
                canvas.tool = PKEraserTool(.bitmap)
            } else {
                // Use inking tool with current properties
                let inkingTool = PKInkingTool(selectedTool, color: selectedColor, width: lineWidth)
                canvas.tool = inkingTool
            }
        }
        
        /// Set a custom tool on all canvases
        func setCustomTool(type: PKInkingTool.InkType, color: UIColor, width: CGFloat) {
            // Use CanvasManager to set tool on all canvases
            CanvasManager.shared.setTool(type, color: color, width: width)
        }
        
        /// Clear tool selection on all canvases
        func clearToolSelection() {
            // Use CanvasManager to clear tool selection (will disable interactions)
            CanvasManager.shared.clearToolSelection()
        }
        
        /// Handle tool change events from EventBus
        func handleToolChangeEvent(_ event: ToolEvents.ToolChanged) {
            // Update local tool properties
            self.selectedTool = event.tool
            self.selectedColor = event.color
            self.lineWidth = event.width
            
            // Update all active canvases with the new tool
            for canvasView in canvasViews.values {
                applyCurrentTool(to: canvasView)
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
        func updateCanvasRenderingForZoomScale(_ zoomScale: CGFloat) {
            // Update the zoom scale in the coordinate manager
            CoordinateSpaceManager.shared.updateZoomScale(zoomScale)
            
            // Use CanvasManager to adjust quality for all canvases
            for (_, canvasView) in canvasViews {
                CanvasManager.shared.adjustQualityForZoom(canvasView, zoomScale: zoomScale)
            }
        }
        
        /// Get app settings
        func getAppSettings() -> AppSettingsModel? {
            return parent.appSettings
        }
        
        // Add a helper method to visualize container-to-scrollview coordinate conversion
        func visualizeContainerCoordinates(in scrollView: UIScrollView, container: UIView, pageIndex: Int) {
            // Coordinate visualization disabled - this method now does nothing
            // Previously, this would display coordinate information for debugging purposes
        }
        
        // MARK: - Scrolling Behavior and Page Visibility
        func updateVisiblePageIndex() {
            // Get the visible rect in container coordinates
            guard let scrollView = containerView?.superview as? UIScrollView,
                  let container = containerView else { return }
            
            let visibleRect = scrollView.convert(scrollView.bounds, to: container)
            
            // Find the page that has the most overlap with the visible area
            var maxOverlapArea: CGFloat = 0
            var visiblePageIndex = currentlyVisiblePageIndex
            
            for (index, _) in parent.pages.enumerated() {
                // Look for views with tag == index + 100 (matching what we set in layoutPages)
                let pageView = container.subviews.first { $0.tag == index + 100 }
                
                if let pageView = pageView {
                    let pageRect = pageView.frame
                    let intersection = pageRect.intersection(visibleRect)
                    
                    if !intersection.isNull {
                        let overlapArea = intersection.width * intersection.height
                        if overlapArea > maxOverlapArea {
                            maxOverlapArea = overlapArea
                            visiblePageIndex = index
                        }
                    }
                }
            }
            
            // Only send notification if the visible page actually changed
            if visiblePageIndex != currentlyVisiblePageIndex {
                currentlyVisiblePageIndex = visiblePageIndex
                print("📄 Visible page changed to: \(visiblePageIndex + 1)")
                EventBus.shared.publish(PageEvents.VisiblePageChanged(pageIndex: visiblePageIndex))
            }
        }
        
        // MARK: - Drawing Management and Tool Support
        @objc func handleDrawingStarted(_ pageID: UUID) {
            // Find the page index for this ID
            if let pageIndex = parent.pages.firstIndex(where: { $0.id == pageID }) {
                // Send the notification with the page ID
                EventBus.shared.publish(DrawingEvents.DrawingStarted(pageId: pageID))
            }
        }
        
        @objc func handleDrawingChanged(_ pageID: UUID) {
            // Find the canvas view and page for this ID
            guard let canvasView = canvasViews[pageID],
                  let pageIndex = parent.pages.firstIndex(where: { $0.id == pageID }) else { return }
            
            // Convert drawing to data and update the page
            let drawing = canvasView.drawing
            let drawingData = try? drawing.dataRepresentation()
            
            // Update the page model
            if let validDrawingData = drawingData {
                parent.pages[pageIndex].drawingData = validDrawingData
            } else {
                parent.pages[pageIndex].drawingData = Data()
            }
            
            // Notify that the drawing changed
            EventBus.shared.publish(DrawingEvents.PageDrawingChanged(pageId: pageID, drawingData: drawingData))
        }
        
        // MARK: - Grid and Debug Visualization
        
        @objc func toggleCoordinateGrid() {
            // Find the existing grid view
            let existingGrid = containerView?.subviews.first { $0.tag == 7777 }
            
            if let existingGrid = existingGrid {
                // Toggle visibility of existing grid
                existingGrid.isHidden.toggle()
                
                // Notify about the state change
                EventBus.shared.publish(GridEvents.GridStateChanged(isVisible: !existingGrid.isHidden))
                
                print("📐 Coordinate grid visibility toggled: \(!existingGrid.isHidden)")
            } else {
                // Create grid if it doesn't exist
                print("📐 Creating coordinate grid overlay")
                addCoordinateGrid()
                
                // Notify about the state change
                EventBus.shared.publish(GridEvents.GridStateChanged(isVisible: true))
            }
        }
        
        // Add a coordinate grid to the view
        @objc func addCoordinateGrid(_ notification: Notification? = nil) {
            guard let scrollView = scrollView, let container = containerView else { return }
            
            // If gridView already exists, just toggle visibility
            if let existingGrid = gridView {
                existingGrid.isHidden.toggle()
                
                // Notify about grid state change
                EventBus.shared.publish(GridEvents.GridStateChanged(isVisible: !existingGrid.isHidden))
                
                print("📐 Coordinate grid visibility toggled: \(!existingGrid.isHidden)")
                return
            }
            
            print("📐 Creating coordinate grid overlay")
            
            // Create the grid view that will contain all grid elements
            let gridView = UIView(frame: container.bounds)
            gridView.tag = 999
            gridView.isUserInteractionEnabled = false
            container.addSubview(gridView)
            self.gridView = gridView
            
            // Grid lines every 100 points
            let gridSize: CGFloat = 100
            
            // Calculate how many grid lines we need in each direction
            let horizontalLines = Int(ceil(container.bounds.height / gridSize))
            let verticalLines = Int(ceil(container.bounds.width / gridSize))
            
            // Add horizontal grid lines
            for i in 0...horizontalLines {
                let y = CGFloat(i) * gridSize
                
                let line = UIView(frame: CGRect(x: 0, y: y, width: container.bounds.width, height: 2))
                
                // Highlight page boundaries with different colors
                let isPageBoundary = isPageBoundary(y: y)
                let isPageStart = isPageStart(y: y)
                let isSpacingArea = isSpacingArea(y: y)
                
                if isPageStart {
                    // Start of a page - use green
                    line.backgroundColor = UIColor.green.withAlphaComponent(0.5)
                    line.frame.size.height = 4 // Thicker line
                } else if isSpacingArea {
                    // Inside spacing area - use yellow
                    line.backgroundColor = UIColor.yellow.withAlphaComponent(0.5)
                } else if isPageBoundary {
                    // End of a page - use red
                    line.backgroundColor = UIColor.red.withAlphaComponent(0.5)
                    line.frame.size.height = 4 // Thicker line
                } else {
                    // Regular grid line - use blue
                    line.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
                }
                
                gridView.addSubview(line)
                
                // Add coordinate label
                let label = UILabel()
                label.text = "\(Int(y))"
                label.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
                label.textColor = UIColor.white
                label.backgroundColor = isPageBoundary ? UIColor.red.withAlphaComponent(0.7) : 
                                      isPageStart ? UIColor.green.withAlphaComponent(0.7) :
                                      UIColor.blue.withAlphaComponent(0.7)
                label.textAlignment = .center
                label.sizeToFit()
                
                if isPageStart || isPageBoundary {
                    let pageIndex = getPageIndex(for: y)
                    if isPageStart {
                        label.text = "Page \(pageIndex + 1) Start: \(Int(y))"
                    } else if isPageBoundary {
                        label.text = "Page \(pageIndex) End: \(Int(y))"
                    }
                    label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
                    label.sizeToFit()
                }
                
                label.frame = CGRect(
                    x: 10,
                    y: y - (label.frame.height / 2),
                    width: label.frame.width + 8,
                    height: label.frame.height
                )
                label.layer.cornerRadius = 3
                label.layer.masksToBounds = true
                
                gridView.addSubview(label)
            }
            
            // Add vertical grid lines
            for i in 0...verticalLines {
                let x = CGFloat(i) * gridSize
                
                let line = UIView(frame: CGRect(x: x, y: 0, width: 1, height: container.bounds.height))
                line.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
                gridView.addSubview(line)
                
                // Add coordinate label
                let label = UILabel()
                label.text = "\(Int(x))"
                label.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
                label.textColor = UIColor.white
                label.backgroundColor = UIColor.blue.withAlphaComponent(0.7)
                label.textAlignment = .center
                label.sizeToFit()
                
                label.frame = CGRect(
                    x: x - (label.frame.width / 2),
                    y: 10,
                    width: label.frame.width + 8,
                    height: label.frame.height
                )
                label.layer.cornerRadius = 3
                label.layer.masksToBounds = true
                
                gridView.addSubview(label)
            }
            
            // Add scale indicator at the bottom
            addScaleIndicator(to: gridView, in: container)
            
            // Notify about grid state change
            EventBus.shared.publish(GridEvents.GridStateChanged(isVisible: true))
        }
        
        // Helpers for page boundary detection in grid
        private func isPageBoundary(y: CGFloat) -> Bool {
            let pageHeight = parent.pageSize.height
            let pageSpacing = parent.pageSpacing
            let totalPageHeight = pageHeight + pageSpacing
            
            // Check if this y position is at the end of a page
            for i in 0..<parent.pages.count {
                let pageStartY = CGFloat(i) * totalPageHeight
                let pageEndY = pageStartY + pageHeight
                
                // Use a small tolerance to account for floating point precision
                if abs(y - pageEndY) < 5 {
                    return true
                }
            }
            return false
        }
        
        private func isPageStart(y: CGFloat) -> Bool {
            let pageHeight = parent.pageSize.height
            let pageSpacing = parent.pageSpacing
            let totalPageHeight = pageHeight + pageSpacing
            
            // Check if this y position is at the start of a page
            for i in 0..<parent.pages.count {
                let pageStartY = CGFloat(i) * totalPageHeight
                
                // Use a small tolerance to account for floating point precision
                if abs(y - pageStartY) < 5 {
                    return true
                }
            }
            return false
        }
        
        private func isSpacingArea(y: CGFloat) -> Bool {
            let pageHeight = parent.pageSize.height
            let pageSpacing = parent.pageSpacing
            let totalPageHeight = pageHeight + pageSpacing
            
            // Check if this y position is within the spacing between pages
            for i in 0..<(parent.pages.count - 1) {
                let pageStartY = CGFloat(i) * totalPageHeight
                let pageEndY = pageStartY + pageHeight
                let nextPageStartY = pageEndY + pageSpacing
                
                if y > pageEndY && y < nextPageStartY {
                    return true
                }
            }
            return false
        }
        
        private func getPageIndex(for y: CGFloat) -> Int {
            let pageHeight = parent.pageSize.height
            let pageSpacing = parent.pageSpacing
            let totalPageHeight = pageHeight + pageSpacing
            
            let index = Int(y / totalPageHeight)
            return min(max(0, index), parent.pages.count - 1)
        }
        
        // Add a method to add scale indicator to the grid
        private func addScaleIndicator(to gridView: UIView, in container: UIView) {
            // Add scale indicator at the bottom
            let scaleLabel = UILabel()
            scaleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)  // Increased opacity
            scaleLabel.textColor = UIColor.white
            scaleLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
            scaleLabel.layer.cornerRadius = 8
            scaleLabel.layer.masksToBounds = true
            scaleLabel.textAlignment = .center
            scaleLabel.frame = CGRect(x: 10, y: container.bounds.height - 30, width: 250, height: 30)  // Increased size
            gridView.addSubview(scaleLabel)
            
            // Create timer to update scale label periodically
            let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak scrollView, weak container] _ in
                guard let scrollView = scrollView, let container = container else { return }
                
                // Get current zoom and position
                let zoom = scrollView.zoomScale
                let offset = scrollView.contentOffset
                let containerPos = container.frame.origin
                
                // Calculate pixels-per-point at current zoom
                let pixelsPerPoint = UIScreen.main.scale * zoom
                
                // Get page dimensions and spacing
                let pageHeight = self.parent.pageSize.height
                let pageSpacing = self.parent.pageSpacing
                let totalPageHeight = pageHeight + pageSpacing
                
                // Calculate visible page
                let visiblePage = self.determinePageForOffset(offset.y)
                
                // Update the label with current information
                scaleLabel.text = String(format: "ZOOM: %.2f (%.1f PPI) | CONTAINER: (%.0f, %.0f) | PAGE: %d/%d | PAGE HEIGHT: %.0f + %.0f spacing",
                                  zoom, pixelsPerPoint, containerPos.x, containerPos.y, visiblePage + 1, self.parent.pages.count, pageHeight, pageSpacing)
                
                scaleLabel.sizeToFit()
                
                var frame = scaleLabel.frame
                frame.size.width = min(max(frame.size.width + 8, 250), container.bounds.width - 20)
                frame.size.height += 4
                frame.origin.y = container.bounds.height - frame.height - 10
                scaleLabel.frame = frame
            }
            
            // Run the timer immediately for initial display
            timer.fire()
            
            // Store timer as associated object
            objc_setAssociatedObject(gridView, "scaleUpdateTimer", timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        // Helper method to determine the page index for a given Y offset
        private func determinePageForOffset(_ offsetY: CGFloat) -> Int {
            guard let scrollView = scrollView, let container = containerView else {
                return 0
            }
            
            // First convert the offset to a point in the container's coordinate system
            let pointInContainer = scrollView.convert(CGPoint(x: 0, y: offsetY + scrollView.bounds.height/2), to: container)
            
            // Calculate the visible page based on the container coordinates
            let pageHeight = parent.pageSize.height
            let pageSpacing = parent.pageSpacing
            let totalPageHeight = pageHeight + pageSpacing
            
            // Calculate page index, but clamp it to valid range
            let pageIndex = Int(pointInContainer.y / totalPageHeight)
            return min(max(0, pageIndex), parent.pages.count - 1)
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
        
        // Add handler for force template refresh notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceTemplateRefresh"),
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.pages.isEmpty { return }
                
                print("🖌️ ForceTemplateRefresh received - updating all canvas templates")
                print("🖌️ Using template type: \(self.template.type.rawValue)")
                
                // Make a copy of the current template to ensure consistency
                let templateToApply = self.template
                
                // Update template on all existing canvas views without removing them
                for (_, canvasView) in context.coordinator.canvasViews {
                    // Clear existing template
                    if let sublayers = canvasView.layer.sublayers {
                        for layer in sublayers where layer.name == "TemplateLayer" {
                            layer.removeFromSuperlayer()
                        }
                    }
                    
                    // Remove any template subviews
                    for subview in canvasView.subviews where subview.tag == 888 {
                        subview.removeFromSuperview()
                    }
                    
                    // Apply the template using our updated method
                    context.coordinator.applyTemplate(to: canvasView, template: templateToApply)
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
        
        // Position indicators disabled - removed setupPositionIndicators call
        
        // Add notification observers
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.addCoordinateGrid),
            name: NSNotification.Name("ToggleCoordinateGrid"),
            object: nil
        )
        
        // Add observer for layout update requests
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.layoutPages),
            name: NSNotification.Name("RequestLayoutUpdate"),
            object: nil
        )
        
        // Listen for template changes via notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TemplateChanged"), 
            object: nil, 
            queue: .main
        ) { notification in
            print("🖌️ MultiPageUnifiedScrollView: TemplateChanged NOTIFICATION received - decoding template data")
            
            // Log what's in the notification userInfo
            if let userInfo = notification.userInfo {
                print("🖌️ TemplateChanged userInfo keys: \(userInfo.keys.map { $0 as? String ?? "unknown" }.joined(separator: ", "))")
            } else {
                print("🖌️ TemplateChanged notification had NO userInfo")
            }
            
            if let templateData = notification.userInfo?["template"] as? Data {
                print("🖌️ Template data found, size: \(templateData.count) bytes")
                do {
                    let updatedTemplate = try JSONDecoder().decode(CanvasTemplate.self, from: templateData)
                    print("🖌️ Successfully decoded template type: \(updatedTemplate.type.rawValue)")
                    
                    DispatchQueue.main.async {
                        print("🖌️ MultiPageUnifiedScrollView: Changing from template type: \(self.template.type.rawValue) to: \(updatedTemplate.type.rawValue)")
                        
                        // Update our template property with the new template
                        self.template = updatedTemplate
                        
                        // Log the number of canvas views we're updating
                        print("🖌️ Updating template on \(context.coordinator.canvasViews.count) canvas views")
                        
                        // Update template on all existing canvas views
                        var index = 0
                        for (_, canvasView) in context.coordinator.canvasViews {
                            // Use the specific updatedTemplate to ensure all views get the new template
                            context.coordinator.applyTemplate(to: canvasView, template: updatedTemplate)
                            index += 1
                        }
                    }
                } catch {
                    print("❌ Error decoding template data: \(error)")
                }
            } else {
                print("❌ No template data found in notification userInfo")
            }
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
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
            
            // Log the template we're applying
            print("🖌️ Updating templates in updateUIView")
            print("🖌️ Using template type: \(template.type.rawValue)")
            
            // Apply this template to all canvas views
            for (_, canvasView) in context.coordinator.canvasViews {
                // Call applyTemplate with the current template
                context.coordinator.applyTemplate(to: canvasView, template: template)
            }
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
        
        // Update grid if it exists and debug mode is enabled
        if GlobalSettings.debugModeEnabled, 
           let container = context.coordinator.containerView,
           container.subviews.contains(where: { $0.tag == 7777 }) {
            context.coordinator.addCoordinateGrid()
        }
    }
    
    /// Request a layout update for all pages
    func requestLayoutUpdate() {
        isPerformingLayout = true
        
        // Small delay to allow state changes to propagate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPerformingLayout = false
            
            // Post a notification that will be handled by the coordinator
            NotificationCenter.default.post(name: NSNotification.Name("RequestLayoutUpdate"), object: nil)
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
