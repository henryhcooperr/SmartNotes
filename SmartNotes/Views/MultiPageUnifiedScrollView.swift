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
    
    // Handle view size changes by updating zoom constraints
    func updateMinZoomScaleForSize(_ size: CGSize) {
        guard let containerView = context?.containerView, 
              size.width > 0, size.height > 0 else { return }
    
        let containerSize = containerView.frame.size
        let widthScale = size.width / containerSize.width
        let heightScale = size.height / containerSize.height
    
        // Use the smaller scale to ensure content fits within view
        let minScale = max(0.25, min(widthScale, heightScale))
    
        minimumZoomScale = minScale
        
        // If current zoom is less than new minimum, update it
        if zoomScale < minScale {
            zoomScale = minScale
        }
        
        // After changing zoom scale, update content insets and centering
        context?.updateContentInsetsForZoom(self)
        context?.centerContentIfNeeded(self)
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
    
    // Minimal spacing so there's a slight boundary between pages
    let pageSpacing: CGFloat = 2 * GlobalSettings.resolutionScaleFactor  // base spacing * scale factor
    
    class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
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
        
        init(_ parent: MultiPageUnifiedScrollView) {
            self.parent = parent
            super.init()
        }
        
        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return containerView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // DO NOT force centering during active zooming as that fights with iOS's natural pinch behavior
            // Instead, just update the content insets to provide proper padding if needed
            updateContentInsetsForZoom(scrollView)
            
            // Still update rendering quality for different zoom levels
            updateCanvasRenderingForZoomScale(scrollView.zoomScale)
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // Reduce resolution during scrolling for better performance
            for (_, canvasView) in canvasViews {
                canvasView.setTemporaryLowResolutionMode(true)
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // If not decelerating, restore resolution immediately
            if !decelerate {
                for (_, canvasView) in canvasViews {
                    canvasView.setTemporaryLowResolutionMode(false)
                }
                
                // Re-center and enforce bounds if not continuing to decelerate
                centerContentInScrollView()
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // Restore resolution after scrolling stops
            for (_, canvasView) in canvasViews {
                canvasView.setTemporaryLowResolutionMode(false)
            }
        }
        
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            guard let appSettings = getAppSettings(), appSettings.optimizeDuringInteraction else { return }
            
            // Reduce resolution during zooming for better performance
            for (_, canvasView) in canvasViews {
                canvasView.setTemporaryLowResolutionMode(true)
            }
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            guard let appSettings = getAppSettings() else { return }
            
            // Always restore resolution after zooming stops
            if appSettings.optimizeDuringInteraction {
                for (_, canvasView) in canvasViews {
                    canvasView.setTemporaryLowResolutionMode(false)
                }
            }
            
            // Log the final zoom scale for debugging
            if GlobalSettings.debugModeEnabled {
                print("🔎 Final zoom scale: \(scale)")
            }
            
            // AFTER zooming completes:
            // 1. Center the content if it's smaller than the view
            // 2. Enforce scroll bounds to prevent scrolling past edges
            centerContentIfNeeded(scrollView)
            
            // Set the appropriate directional lock based on content size
            updateDirectionalLock(scrollView)
        }
        
        // Center content but only if needed (smaller than view or past bounds)
        func centerContentIfNeeded(_ scrollView: UIScrollView) {
            guard let containerView = containerView else { return }
            
            let containerSize = containerView.frame.size
            let scrollViewSize = scrollView.bounds.size
            let scaledWidth = containerSize.width * scrollView.zoomScale
            let scaledHeight = containerSize.height * scrollView.zoomScale
            
            // When content is smaller than view, we rely on content insets to center it
            // We should NOT explicitly set contentOffset.x = -scrollView.contentInset.left
            if scaledWidth <= scrollViewSize.width {
                // Only update directional lock - don't force contentOffset changes
                scrollView.isDirectionalLockEnabled = true
                
                // Only reset the offset if it's significantly off-center and user isn't interacting
                if !scrollView.isTracking && !scrollView.isDecelerating && !scrollView.isZooming {
                    // When content fits, offset should be 0 (letting contentInset handle centering)
                    let targetX: CGFloat = 0.0
                    let currentX = scrollView.contentOffset.x
                    
                    // Only reset if significantly off
                    if abs(currentX - targetX) > 1.0 {
                        scrollView.contentOffset.x = 0.0
                    }
                }
            } else {
                // Content is wider than view - enforce min/max bounds
                let minOffsetX: CGFloat = 0.0  // The left edge of the content (not -contentInset.left)
                let maxOffsetX = scaledWidth - scrollViewSize.width
                
                if scrollView.contentOffset.x < minOffsetX {
                    scrollView.contentOffset.x = minOffsetX
                } else if scrollView.contentOffset.x > maxOffsetX {
                    scrollView.contentOffset.x = maxOffsetX
                }
            }
            
            // Handle vertical centering with the same principle
            if scaledHeight <= scrollViewSize.height {
                // Only reset the offset if significantly off and user isn't interacting
                if !scrollView.isTracking && !scrollView.isDecelerating && !scrollView.isZooming {
                    // When content fits height, offset should be 0 (insets handle centering)
                    let targetY: CGFloat = 0.0
                    let currentY = scrollView.contentOffset.y
                    
                    // Only reset if significantly off
                    if abs(currentY - targetY) > 1.0 {
                        scrollView.contentOffset.y = 0.0
                    }
                }
            }
            
            // Update scroll indicators after centering
            updateScrollIndicatorPosition()
        }
        
        // Update directional lock based on content size relative to view
        func updateDirectionalLock(_ scrollView: UIScrollView) {
            guard let containerView = containerView else { return }
            
            let containerSize = containerView.frame.size
            let scrollViewSize = scrollView.bounds.size
            let scaledWidth = containerSize.width * scrollView.zoomScale
            
            // Only enable directional lock when content fits within the view width
            scrollView.isDirectionalLockEnabled = (scaledWidth <= scrollViewSize.width)
        }
        
        func scrollViewDidLayoutSubviews(_ scrollView: UIScrollView) {
            // Update insets to maintain proper padding when layout changes
            updateContentInsetsForZoom(scrollView)
            
            // After layout changes (like rotation), we can safely center content if needed
            centerContentIfNeeded(scrollView)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // We want to be careful about enforcing bounds during scrolling
            // Don't interfere with active user interaction
            if !scrollView.isTracking && !scrollView.isDecelerating && !scrollView.isZooming {
                // Only enforce bounds when the user isn't actively interacting
                enforceScrollBoundsIfNeeded(scrollView)
            }
        }
        
        // A less aggressive bounds enforcer that only acts when clearly needed
        func enforceScrollBoundsIfNeeded(_ scrollView: UIScrollView) {
            guard let containerView = containerView else { return }
            
            let containerSize = containerView.frame.size
            let scrollViewSize = scrollView.bounds.size
            let scaledWidth = containerSize.width * scrollView.zoomScale
            
            // Only apply constraints if content is smaller than view
            // (iOS handles the rest correctly for larger content)
            if scaledWidth <= scrollViewSize.width {
                // Center horizontally when content is smaller than view
                // Instead of setting to -contentInset.left, set to 0 to let insets handle centering
                scrollView.contentOffset.x = 0.0
            }
            
            let scaledHeight = containerSize.height * scrollView.zoomScale
            if scaledHeight <= scrollViewSize.height {
                // Center vertically when content is smaller than view height
                // Use 0 instead of -contentInset.top
                scrollView.contentOffset.y = 0.0
            }
        }
        
        // MARK: - Content Positioning
        
        // A simpler, more reliable approach to centering
        func centerContentInScrollView() {
            guard let scrollView = scrollView, let containerView = containerView else { return }
            
            let containerSize = containerView.frame.size
            let scrollViewSize = scrollView.bounds.size
            
            // Calculate the scaled container size
            let scaledWidth = containerSize.width * scrollView.zoomScale
            let scaledHeight = containerSize.height * scrollView.zoomScale
            
            // Set the content insets to center the content
            let horizontalInset = max((scrollViewSize.width - scaledWidth) / 2, 0.0)
            let verticalInset = max((scrollViewSize.height - scaledHeight) / 2, 0.0)
            
            // Apply the insets
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
            
            // Update scroll indicators to match content boundaries
            updateScrollIndicatorPosition()
            
            // Additional handling for centering based on current zoom level
            // When content fits within view, keep it centered
            if scaledWidth < scrollViewSize.width {
                // Disable horizontal scrolling when content is smaller than the view.
                if !scrollView.isTracking && !scrollView.isDecelerating {
                    // Set to 0 instead of manipulating with content insets
                    scrollView.contentOffset.x = 0.0
                    scrollView.isDirectionalLockEnabled = true
                }
            } else {
                // Content is wider than the scroll view; clamp the offset to the valid range
                let maxOffsetX = scaledWidth - scrollViewSize.width
                if !scrollView.isTracking && !scrollView.isDecelerating {
                    if scrollView.contentOffset.x < 0.0 {
                        scrollView.contentOffset.x = 0.0
                    } else if scrollView.contentOffset.x > maxOffsetX {
                        scrollView.contentOffset.x = maxOffsetX
                    }
                }
                scrollView.isDirectionalLockEnabled = false
            }
            
            // When content height is less than view height, center vertically
            if scaledHeight < scrollViewSize.height {
                if !scrollView.isTracking && !scrollView.isDecelerating {
                    // Set to 0 to let content insets handle centering
                    scrollView.contentOffset.y = 0.0
                }
            }
            
            // After setting insets and initial position, enforce bounds
            // This ensures we don't end up in an invalid scroll position
            if !scrollView.isTracking && !scrollView.isDecelerating {
                enforceScrollBounds()
            }
        }
        
        // MARK: - PKCanvasViewDelegate
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Identify which page it belongs to
            guard let pageID = canvasView.tagID,
                  let pageIndex = parent.pages.firstIndex(where: { $0.id == pageID }) else {
                return
            }
            
            // Save the updated drawing
            let drawingData = canvasView.drawing.dataRepresentation()
            
            DispatchQueue.main.async {
                self.parent.pages[pageIndex].drawingData = drawingData
                
                // Check if we need to add a page after updating the model
                if !self.isInitialLoad {
                    self.checkForNextPageNeeded(pageIndex: pageIndex, canvasView: canvasView)
                }
            }
            
            // Notify that content changed
            ThumbnailGenerator.invalidateThumbnail(for: pageID)
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
                
                // Apply the template lines/dots
                applyTemplate(to: cv)
            }
            
            print("📄 Layout complete: created \(newViewsCreated) new canvas views, updated \(existingViewsUpdated) existing views")
            
            // Update container frame
            let totalHeight = max(1, CGFloat(parent.pages.count)) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            
            // SIMPLIFY: Keep the container size exactly matching the content
            // This ensures content and scroll indicators align correctly
            container.frame = CGRect(
                x: 0, 
                y: 0, 
                width: parent.pageSize.width,
                height: totalHeight
            )
            
            // Position the pages within the container
            for (index, page) in parent.pages.enumerated() {
                if let cv = canvasViews[page.id] {
                    let yPos = CGFloat(index) * (parent.pageSize.height + parent.pageSpacing)
                    // Center horizontally within the container
                    cv.frame = CGRect(
                        x: 0,
                        y: yPos,
                        width: parent.pageSize.width,
                        height: parent.pageSize.height
                    )
                }
            }
            
            // Update scroll view content size to match the container size exactly
            scrollView.contentSize = container.frame.size
            
            // Calculate and update insets for proper centering
            centerContentInScrollView()
            
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
            // Optimize for high resolution
            canvasView.optimizeForHighResolution()
            
            // Ensure no content insets on the canvas itself
            canvasView.contentInset = .zero
            
            // Configure finger drawing
            let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
            if #available(iOS 16.0, *) {
                canvasView.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
            } else {
                canvasView.allowsFingerDrawing = !disableFingerDrawing
            }
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
        
        /// Update canvas rendering quality based on zoom scale
        func updateCanvasRenderingForZoomScale(_ scale: CGFloat) {
            for (_, canvasView) in canvasViews {
                canvasView.adjustQualityForZoom(scale)
            }
        }
        
        /// Get app settings
        func getAppSettings() -> AppSettingsModel? {
            return parent.appSettings
        }
        
        // A separate method just to enforce scroll bounds without changing the center
        func enforceScrollBounds() {
            guard let scrollView = scrollView, let containerView = containerView else { return }
            
            let containerSize = containerView.frame.size
            let scrollViewSize = scrollView.bounds.size
            let scaledWidth = containerSize.width * scrollView.zoomScale
            
            // When content is narrower than the view, keep it centered and prevent any horizontal movement
            if scaledWidth <= scrollViewSize.width {
                // Content fits within view - it should be perfectly centered horizontally
                // Use 0 instead of -scrollView.contentInset.left to let insets handle centering
                scrollView.contentOffset.x = 0.0
                
                // Disable horizontal scrolling entirely when content fits in view
                scrollView.isDirectionalLockEnabled = true
            } else {
                // Content is wider than view - enforce min/max bounds
                
                // Calculate left bound (minimum x offset)
                let minOffsetX: CGFloat = 0.0 // Use 0 instead of -scrollView.contentInset.left
                
                // Calculate right bound (maximum x offset)
                // This needs to account for content size but not insets anymore
                let maxOffsetX = scaledWidth - scrollViewSize.width
                
                // Log the bounds for debugging
                if GlobalSettings.debugModeEnabled {
                    print("📏 Scroll bounds: min=\(minOffsetX), max=\(maxOffsetX), current=\(scrollView.contentOffset.x)")
                }
                
                // Apply bounds restrictions symmetrically
                if scrollView.contentOffset.x < minOffsetX {
                    scrollView.contentOffset.x = minOffsetX
                } else if scrollView.contentOffset.x > maxOffsetX {
                    scrollView.contentOffset.x = maxOffsetX
                }
                
                // Allow free scrolling when zoomed in
                scrollView.isDirectionalLockEnabled = false
            }
            
            // Similarly, enforce vertical bounds
            let scaledHeight = containerSize.height * scrollView.zoomScale
            if scaledHeight <= scrollViewSize.height {
                // Center vertically - use 0 instead of -scrollView.contentInset.top
                scrollView.contentOffset.y = 0.0
            }
            
            // Update scroll indicator position after enforcing bounds
            updateScrollIndicatorPosition()
        }
        
        // Add dedicated method for updating scroll indicator position
        func updateScrollIndicatorPosition() {
            guard let scrollView = scrollView, let containerView = containerView else { return }
            
            let containerSize = containerView.frame.size
            let scrollViewSize = scrollView.bounds.size
            let scaledWidth = containerSize.width * scrollView.zoomScale
            let scaledHeight = containerSize.height * scrollView.zoomScale
            
            // Calculate the horizontal and vertical insets for content centering
            let horizontalInset = max((scrollViewSize.width - scaledWidth) / 2, 0.0)
            let verticalInset = max((scrollViewSize.height - scaledHeight) / 2, 0.0)
            
            // Always keep scroll indicators at the boundary of the actual content, not the scrollView
            // This makes the indicators match the visible content edges
            scrollView.scrollIndicatorInsets = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
            
            // Force immediate update of scroll indicator
            scrollView.flashScrollIndicators()
        }
        
        // Add a dedicated method for updating content insets without repositioning content
        func updateContentInsetsForZoom(_ scrollView: UIScrollView) {
            guard let containerView = containerView else { return }
            
            let containerSize = containerView.frame.size
            let scrollViewSize = scrollView.bounds.size
            
            // Calculate the scaled content size
            let scaledWidth = containerSize.width * scrollView.zoomScale
            let scaledHeight = containerSize.height * scrollView.zoomScale
            
            // Calculate insets (positive only when content is smaller than view)
            let horizontalInset = max((scrollViewSize.width - scaledWidth) / 2, 0.0)
            let verticalInset = max((scrollViewSize.height - scaledHeight) / 2, 0.0)
            
            // Apply insets without changing the content offset during zoom
            // UIScrollView automatically centers content with these insets
            // when the content is smaller than the view
            let newInsets = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
            
            // Only update insets if they changed significantly to avoid visual glitches
            let currentInsets = scrollView.contentInset
            if abs(newInsets.left - currentInsets.left) > 0.5 ||
               abs(newInsets.top - currentInsets.top) > 0.5 ||
               abs(newInsets.right - currentInsets.right) > 0.5 ||
               abs(newInsets.bottom - currentInsets.bottom) > 0.5 {
                scrollView.contentInset = newInsets
            }
            
            // Update scroll indicator insets to match content insets
            // This ensures they're always aligned with the actual content boundaries
            updateScrollIndicatorPosition()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        MultiPageUnifiedScrollView.updateCounter += 1
        
        let scrollView = MultiPageScrollView()
        scrollView.delegate = context.coordinator
        
        // Set more reasonable zoom constraints
        // Minimum zoom: shouldn't be able to zoom out much beyond fitting the page
        // Because we're using a resolution scale factor for drawing quality,
        // we need to adjust our zoom limits accordingly
        
        // For minimum zoom, we want to limit to approximately 90% of original size
        // this prevents excessive zooming out while still allowing some flexibility
        scrollView.minimumZoomScale = 0.9 / GlobalSettings.resolutionScaleFactor
        
        // For maximum zoom, 4x is usually sufficient for detailed work
        scrollView.maximumZoomScale = 4.0 / GlobalSettings.resolutionScaleFactor
        
        // Improve scrolling behavior
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.indicatorStyle = .black  // Makes them more visible against light backgrounds
        scrollView.backgroundColor = UIColor.systemGray5
        
        // Disable bouncing for more precise control
        scrollView.bounces = false
        
        // Set zoom to center on tapped point
        scrollView.bouncesZoom = false
        
        // Create container view for all canvases
        let container = UIView()
        container.backgroundColor = UIColor.systemGray5
        scrollView.addSubview(container)
        
        // Save references
        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = container
        
        // If pages is empty, create at least one page
        if pages.isEmpty {
            let newPage = Page()
            DispatchQueue.main.async {
                self.pages = [newPage]
            }
        }
        
        // Set initial zoom scale
        scrollView.zoomScale = 1.0 / GlobalSettings.resolutionScaleFactor
        
        // Initialize scroll indicators with proper positioning
        // This prevents them from appearing in the wrong position initially
        scrollView.scrollIndicatorInsets = .zero
        scrollView.verticalScrollIndicatorInsets = .zero
        
        // Store initial size for later comparison
        context.coordinator.previousSize = scrollView.bounds.size
        
        // Listen for template refresh notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshTemplate"),
            object: nil,
            queue: .main
        ) { _ in
            // Add a small delay to ensure bindings have updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.pages.isEmpty { return }
                
                // Force refresh by clearing and rebuilding canvas views
                if let container = context.coordinator.containerView {
                    // Remove all existing canvas views
                    for subview in container.subviews {
                        subview.removeFromSuperview()
                    }
                    context.coordinator.canvasViews.removeAll()
                    
                    // Force full redraw
                    context.coordinator.layoutPages()
                }
            }
        }
        
        // Listen for sidebar open/close notifications that might affect centering
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SidebarVisibilityChanged"),
            object: nil, 
            queue: .main
        ) { _ in
            // Re-center after sidebar visibility changes with our improved centering logic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Update content insets first
                context.coordinator.updateContentInsetsForZoom(scrollView)
                // Then center the content
                context.coordinator.centerContentIfNeeded(scrollView)
            }
        }
        
        // Perform initial layout with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.layoutPages()
            
            // Calculate and set appropriate min zoom after layout
            if let container = context.coordinator.containerView {
                // Initialize with proper content insets
                context.coordinator.updateContentInsetsForZoom(scrollView)
                
                // Properly center after layout
                context.coordinator.centerContentIfNeeded(scrollView)
                
                // Mark initial load complete after layout
                context.coordinator.isInitialLoad = false
            }
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
                multiPageScrollView.updateMinZoomScaleForSize(newSize)
            }
        }
        
        // Check if we need to do a full layout update
        let existingViewCount = context.coordinator.canvasViews.count
        let pagesWithoutViews = pages.filter { !context.coordinator.canvasViews.keys.contains($0.id) }
        
        if pagesWithoutViews.isEmpty && existingViewCount == pages.count {
            // We have all the views we need, just update templates if needed
            // This section left intentionally empty - templates are updated only when needed
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
