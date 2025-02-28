//
//  MultiPageUnifiedScrollView.swift
//  SmartNotes
//
//  Created by You on 3/5/25.
//  Updated on 3/6/25 to apply a single note-wide template to each page
//

import SwiftUI
import PencilKit

struct MultiPageUnifiedScrollView: UIViewRepresentable {
    @Binding var pages: [Page]
    @Binding var template: CanvasTemplate
    
    // The standard "paper" size for each page
    let pageSize = CGSize(width: 612, height: 792)
    // Minimal spacing so there's a slight boundary between pages
    let pageSpacing: CGFloat = 10
    
    class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        var parent: MultiPageUnifiedScrollView
        var scrollView: UIScrollView?
        var containerView: UIView?
        
        // Keep references to each PKCanvasView by page ID
        var canvasViews: [UUID: PKCanvasView] = [:]
        
        var toolPicker: PKToolPicker?
        // Avoid repeated triggers during initial load
        var isInitialLoad = true
        
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
            DispatchQueue.main.async {
                self.parent.pages[pageIndex].drawingData = canvasView.drawing.dataRepresentation()
            }
            
            // If user draws near bottom of that page, auto-add next
            if !isInitialLoad {
                checkForNextPageNeeded(pageIndex: pageIndex, canvasView: canvasView)
            }
        }
        
        private func checkForNextPageNeeded(pageIndex: Int, canvasView: PKCanvasView) {
            let bounds = canvasView.drawing.bounds
            let pageHeight = canvasView.bounds.height
            // e.g., if user draws beyond 70% of page
            if bounds.maxY > pageHeight * 0.7 {
                // If it's the last page, add another
                if pageIndex == (parent.pages.count - 1) {
                    DispatchQueue.main.async {
                        self.addPage()
                    }
                }
            }
        }
        
        private func addPage() {
            let newPage = Page(drawingData: Data(), template: nil, pageNumber: parent.pages.count + 1)
            parent.pages.append(newPage)
            print("📝 Auto-added a new page. Total: \(parent.pages.count)")
        }
        
        // Called by updateUIView whenever pages or template changes
        func layoutPages() {
            guard let container = containerView,
                  let scrollView = scrollView else { return }
            
            // Remove subviews for any pages that no longer exist
            for subview in container.subviews {
                if let cv = subview as? PKCanvasView {
                    if !parent.pages.contains(where: { $0.id == cv.tagID }) {
                        cv.removeFromSuperview()
                        canvasViews.removeValue(forKey: cv.tagID!)
                    }
                }
            }
            
            // Ensure each page has a PKCanvasView
            for (index, page) in parent.pages.enumerated() {
                let cv: PKCanvasView
                if let existing = canvasViews[page.id] {
                    cv = existing
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
            
            // Update container/frame/scroll content
            let totalHeight = CGFloat(parent.pages.count) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            container.frame = CGRect(x: 0, y: 0, width: parent.pageSize.width, height: totalHeight)
            scrollView.contentSize = container.frame.size
            
            centerContainer(scrollView: scrollView)
        }
        
        /// Re-apply the user's chosen template lines/dots
        private func applyTemplate(to canvasView: PKCanvasView) {
            let t = parent.template
            TemplateRenderer.applyTemplateToCanvas(
                canvasView,
                template: t,
                pageSize: parent.pageSize,
                numberOfPages: 1,   // since each PKCanvasView is just 1 "page"
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
        
        // Layout pages next runloop
        DispatchQueue.main.async {
            context.coordinator.layoutPages()
            context.coordinator.isInitialLoad = false
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // If pages or template changed, re-layout
        context.coordinator.layoutPages()
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
