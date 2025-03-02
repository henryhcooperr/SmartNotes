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

struct MultiPageUnifiedScrollView: UIViewRepresentable {
    // Track which updates are coming from where
    private static var updateCounter = 0
    
    @Binding var pages: [Page]
    @Binding var template: CanvasTemplate
    
    // The standard "paper" size for each page
    let pageSize = CGSize(width: 1224, height: 1584)
    // Minimal spacing so there's a slight boundary between pages
    let pageSpacing: CGFloat = 2
    
    class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        var parent: MultiPageUnifiedScrollView
        var scrollView: UIScrollView?
        var containerView: UIView?
        
        // Keep references to each PKCanvasView by page ID
        var canvasViews: [UUID: PKCanvasView] = [:]
        
        var toolPicker: PKToolPicker?
        // Avoid repeated triggers during initial load
        var isInitialLoad = true
        
        // Track whether pages are being laid out
        var isLayoutingPages = false
        
        init(_ parent: MultiPageUnifiedScrollView) {
            self.parent = parent
            super.init()
            if #available(iOS 14.0, *) {
                self.toolPicker = PKToolPicker()
            } else {
                self.toolPicker = PKToolPicker()
            }
        }
        
        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            // We'll scale the entire container of pages
            return containerView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContainer(scrollView: scrollView)
        }
        
        private func centerContainer(scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let offsetX = max((scrollView.bounds.width - container.frame.width * scrollView.zoomScale) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - container.frame.height * scrollView.zoomScale) * 0.5, 0)
            
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
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
            
            // Print debug info about the drawing
            print("🖌️ Drawing changed on page \(pageIndex+1): \(canvasView.drawing.strokes.count) strokes")
            
            DispatchQueue.main.async {
                self.parent.pages[pageIndex].drawingData = drawingData
                
                // IMPORTANT: Check if we need to add a page AFTER updating the model
                if !self.isInitialLoad {
                    // Always check for new pages needed after drawing changes on any page
                    self.checkForNextPageNeeded(pageIndex: pageIndex, canvasView: canvasView)
                }
            }
        }
        
        private func checkForNextPageNeeded(pageIndex: Int, canvasView: PKCanvasView) {
            print("🔍 Checking if new page needed: current page \(pageIndex+1) of \(parent.pages.count)")
            
            // We want to add a new page if:
            // 1. This is the last page (pageIndex == parent.pages.count - 1)
            // 2. There are strokes on this page (canvasView.drawing.strokes.count > 0)
            
            if pageIndex == (parent.pages.count - 1) && !canvasView.drawing.strokes.isEmpty {
                // This is the last page and it has content
                let hasLastPageAlready = parent.pages.count > pageIndex + 1
                
                if !hasLastPageAlready {
                    print("📝 Last page has content, adding a new blank page")
                    addPage()
                } else {
                    print("📝 Extra page already exists, no need to add another")
                }
            }
        }
        
        private func addPage() {
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
        
        // Called by updateUIView whenever pages or template changes
        func layoutPages() {
            // Prevent re-entrancy
            if isLayoutingPages {
                print("⚠️ Avoiding recursive layoutPages call")
                return
            }
            
            isLayoutingPages = true
            
            guard let container = containerView,
                  let scrollView = scrollView else {
                print("⚠️ layoutPages() called but container or scrollView is nil")
                isLayoutingPages = false
                return
            }
            
            print("📄 Beginning layout of \(parent.pages.count) pages with template \(parent.template.type.rawValue)")
            
            // Check for empty pages array - this shouldn't happen now with our fix
            if parent.pages.isEmpty {
                print("⚠️ Warning: layoutPages() called with empty pages array. No canvas views will be created.")
                isLayoutingPages = false
                return // Exit early instead of continuing
            }
            
            // Remove subviews for any pages that no longer exist
            var removedViews = 0
            for subview in container.subviews {
                if let cv = subview as? PKCanvasView {
                    if let tagID = cv.tagID, !parent.pages.contains(where: { $0.id == tagID }) {
                        cv.removeFromSuperview()
                        canvasViews.removeValue(forKey: tagID)
                        removedViews += 1
                    }
                }
            }
            if removedViews > 0 {
                print("🧹 Removed \(removedViews) canvas views that no longer have pages")
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
                    
                    if let toolPicker = toolPicker {
                        toolPicker.setVisible(true, forFirstResponder: cv)
                        // Make it first responder so the palette appears
                        DispatchQueue.main.async {
                            cv.becomeFirstResponder()
                        }
                        toolPicker.addObserver(cv)
                    }
                    
                    // Respect finger drawing toggle
                    self.applyFingerDrawingPolicy(to: cv)
                    
                    // Save reference
                    canvasViews[page.id] = cv
                    container.addSubview(cv)
                    newViewsCreated += 1
                }
                
                // Frame it at the correct vertical offset
                let xPos: CGFloat = 0
                let yPos = CGFloat(index) * (parent.pageSize.height + parent.pageSpacing)
                cv.frame = CGRect(
                    x: xPos,
                    y: yPos,
                    width: parent.pageSize.width,
                    height: parent.pageSize.height
                )
                
                // Apply the template lines/dots
                applyTemplate(to: cv)
            }
            
            print("📄 Layout complete: created \(newViewsCreated) new canvas views, updated \(existingViewsUpdated) existing views")
            
            // Update container/frame/scroll content
            let totalHeight = max(1, CGFloat(parent.pages.count)) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            container.frame = CGRect(x: 0, y: 0, width: parent.pageSize.width, height: totalHeight)
            scrollView.contentSize = container.frame.size
            
            centerContainer(scrollView: scrollView)
            
            // Reset layout flag
            isLayoutingPages = false
        }
        
        /// Re-apply the user's chosen template lines/dots
        func applyTemplate(to canvasView: PKCanvasView) {
            // Log which template is being applied for debugging
            print("🖋️ Applying template \(parent.template.type.rawValue) to canvas")
            
            // First, make sure to remove any existing template layers
            if let sublayers = canvasView.layer.sublayers {
                for layer in sublayers {
                    if layer.name == "TemplateLayer" {
                        layer.removeFromSuperlayer()
                    }
                }
            }
            
            // Also remove any existing template image views
            for subview in canvasView.subviews where subview.tag == 888 {
                subview.removeFromSuperview()
            }
            
            // Now apply the template with a fresh slate
            TemplateRenderer.applyTemplateToCanvas(
                canvasView,
                template: parent.template,
                pageSize: parent.pageSize,
                numberOfPages: 1,
                pageSpacing: 0
            )
        }
        
        private func applyFingerDrawingPolicy(to canvasView: PKCanvasView) {
            let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
            if #available(iOS 16.0, *) {
                canvasView.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
            } else {
                canvasView.allowsFingerDrawing = !disableFingerDrawing
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // Increment update counter for debugging
        MultiPageUnifiedScrollView.updateCounter += 1
        let currentCreate = MultiPageUnifiedScrollView.updateCounter
        
        print("🔄 makeUIView #\(currentCreate) called with \(pages.count) pages")
        
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        
        // Set the background color so it's not pure black
        scrollView.backgroundColor = UIColor.systemGray5
        
        let container = UIView()
        container.backgroundColor = UIColor.systemGray5
        
        scrollView.addSubview(container)
        
        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = container
        
        // If pages is empty, create at least one page
        if pages.isEmpty {
            print("⚠️ makeUIView: pages array is empty, creating initial page")
            let newPage = Page()
            DispatchQueue.main.async {
                self.pages = [newPage]
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshTemplate"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 Refresh template notification received")
            
            // Log current state for debugging
            print("🔍 Current template: \(self.template.type.rawValue)")
            print("🔍 Current page count: \(self.pages.count)")
            
            // Add a small delay to ensure bindings have updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // If no pages, notify developer
                if self.pages.isEmpty {
                    print("⚠️ Warning: Attempting to refresh template but pages array is empty!")
                    return
                }
                
                // Force refresh by clearing and rebuilding canvas views
                if let container = context.coordinator.containerView {
                    print("🔄 Clearing existing canvas views and rebuilding...")
                    // Remove all existing canvas views
                    for subview in container.subviews {
                        subview.removeFromSuperview()
                    }
                    context.coordinator.canvasViews.removeAll()
                    
                    // Force full redraw
                    context.coordinator.layoutPages()
                    
                    // Additional refresh after a short delay for reliability
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        context.coordinator.layoutPages()
                    }
                }
            }
        }
        
        // Layout pages next runloop with a small delay to ensure initial setup is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔄 Initial layout of pages (delayed)")
            context.coordinator.layoutPages()
            
            // Mark initial load complete after layout
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                context.coordinator.isInitialLoad = false
                print("🔄 Initial load completed")
            }
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Increment update counter for debugging
        MultiPageUnifiedScrollView.updateCounter += 1
        let currentUpdate = MultiPageUnifiedScrollView.updateCounter
        
        print("🔄 updateUIView #\(currentUpdate) called with \(pages.count) pages, template: \(template.type.rawValue)")
        
        // CRITICAL: Don't allow updates while initial load is in progress
        if context.coordinator.isInitialLoad {
            print("⚠️ Update #\(currentUpdate) skipped - initial load in progress")
            return
        }
        
        // Skip update if pages array is empty
        if pages.isEmpty {
            print("⚠️ Update #\(currentUpdate) skipped - pages array is empty")
            return
        }
        
        // Avoid redundant updates by checking if any PKCanvasViews actually need to be created
        // or if we just need to refresh templates
        let existingViewCount = context.coordinator.canvasViews.count
        let pagesWithoutViews = pages.filter { !context.coordinator.canvasViews.keys.contains($0.id) }
        
        if pagesWithoutViews.isEmpty && existingViewCount == pages.count {
            // If we have all the views we need, just update templates
            print("🔄 Update #\(currentUpdate) - All PKCanvasViews exist, only refreshing templates")
            for (pageID, canvasView) in context.coordinator.canvasViews {
                //context.coordinator.applyTemplate(to: canvasView)
            }
        } else {
            // Otherwise do a full layout refresh
            print("🔄 Update #\(currentUpdate) - Need to create/remove PKCanvasViews, doing full layout")
            context.coordinator.layoutPages()
        }
    }
}

// A helper so we can store the page ID on each PKCanvasView
fileprivate extension PKCanvasView {
    private struct AssociatedKeys {
        static var tagIDKey = "tagIDKey"
    }
    
    var tagID: UUID? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.tagIDKey) as? UUID }
        set { objc_setAssociatedObject(self, &AssociatedKeys.tagIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
