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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        MultiPageUnifiedScrollView.updateCounter += 1
        
        let scrollView = MultiPageScrollView()
        scrollView.delegate = context.coordinator
        
        // Simple zoom constraints matching the original code
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        
        // Basic scrolling setup
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.indicatorStyle = .black
        scrollView.backgroundColor = UIColor.systemGray5
        
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
