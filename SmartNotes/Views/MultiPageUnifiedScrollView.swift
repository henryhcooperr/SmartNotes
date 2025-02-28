//
//  MultiPageUnifiedScrollView.swift
//  SmartNotes
//
//  Created by You on 3/5/25.
//

import SwiftUI
import PencilKit

/// This view displays multiple `Page` objects in a single
/// large scrollable/zoomable space, so it feels like one big note.
struct MultiPageUnifiedScrollView: UIViewRepresentable {
    @Binding var pages: [Page]
    
    /// The overall "paper" size for each page (like US Letter, 612x792).
    /// Tweak as desired.
    private let pageSize = CGSize(width: 612, height: 792)
    
    /// Spacing between pages (you can make it small so they appear continuous).
    private let pageSpacing: CGFloat = 10
    
    class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        var parent: MultiPageUnifiedScrollView
        
        /// The main scroll view for pinch/zoom
        var scrollView: UIScrollView?
        
        /// A container UIView that holds multiple PKCanvasViews
        var containerView: UIView?
        
        /// Keep references to each `PKCanvasView` so we can update them
        var canvasViews: [UUID: PKCanvasView] = [:]
        
        /// Track whether we’re in the initial load phase
        var isInitialLoad = true
        
        init(_ parent: MultiPageUnifiedScrollView) {
            self.parent = parent
        }
        
        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            // We want to scale the entire container (which has all pages).
            return containerView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContainer(scrollView: scrollView)
        }
        
        private func centerContainer(scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let offsetX = max((scrollView.bounds.width - container.frame.width * scrollView.zoomScale) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - container.frame.height * scrollView.zoomScale) * 0.5, 0)
            
            scrollView.contentInset = UIEdgeInsets(
                top: offsetY, left: offsetX,
                bottom: offsetY, right: offsetX
            )
        }
        
        // MARK: - PKCanvasViewDelegate
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Find which Page this canvas belongs to
            guard let pageID = canvasView.tagID,
                  let idx = parent.pages.firstIndex(where: { $0.id == pageID }) else {
                return
            }
            
            // Save drawing to pages[idx]
            DispatchQueue.main.async {
                self.parent.pages[idx].drawingData = canvasView.drawing.dataRepresentation()
            }
            
            // If user draws near bottom of this page, auto-add next page
            if !isInitialLoad {
                checkForNextPageNeeded(pageIndex: idx, canvasView: canvasView)
            }
        }
        
        private func checkForNextPageNeeded(pageIndex: Int, canvasView: PKCanvasView) {
            let bounds = canvasView.drawing.bounds
            let pageHeight = canvasView.bounds.height
            // e.g. if user draws beyond 70% of page
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
            let newPage = Page(
                drawingData: Data(),
                template: nil,
                pageNumber: parent.pages.count + 1
            )
            parent.pages.append(newPage)
            // We'll call layoutPages() in updateUIView
        }
        
        // Lays out all PKCanvasViews in the containerView
        func layoutPages() {
            guard let container = containerView,
                  let scrollView = scrollView else { return }
            
            // Remove old subviews if they no longer correspond to `pages`
            for sub in container.subviews {
                if let cv = sub as? PKCanvasView, !parent.pages.contains(where: { $0.id == cv.tagID }) {
                    cv.removeFromSuperview()
                    canvasViews.removeValue(forKey: cv.tagID!)
                }
            }
            
            // Ensure every page has a PKCanvasView
            for (index, page) in parent.pages.enumerated() {
                // If we already have a PKCanvasView for this page, reuse it
                let cv: PKCanvasView
                if let existingCV = canvasViews[page.id] {
                    cv = existingCV
                } else {
                    // Create a new PKCanvasView
                    cv = PKCanvasView()
                    cv.tagID = page.id // custom extension (below)
                    cv.delegate = self
                    cv.drawing = PKDrawing.fromData(page.drawingData)
                    cv.backgroundColor = .white
                    
                    // Setup tool picker
                    let toolPicker = PKToolPicker()
                    toolPicker.setVisible(true, forFirstResponder: cv)
                    toolPicker.addObserver(cv)
                    
                    // Could do finger drawing toggles, etc.
                    if #available(iOS 16.0, *) {
                        cv.drawingPolicy = .anyInput
                    } else {
                        cv.allowsFingerDrawing = true
                    }
                    
                    canvasViews[page.id] = cv
                    container.addSubview(cv)
                }
                
                let xPos: CGFloat = 0
                let yPos = CGFloat(index) * (parent.pageSize.height + parent.pageSpacing)
                cv.frame = CGRect(
                    x: xPos,
                    y: yPos,
                    width: parent.pageSize.width,
                    height: parent.pageSize.height
                )
            }
            
            // Update container frame & scrollView content size
            let totalHeight = CGFloat(parent.pages.count) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            
            container.frame = CGRect(
                x: 0, y: 0,
                width: parent.pageSize.width,
                height: totalHeight
            )
            
            scrollView.contentSize = container.frame.size
            
            // If done loading, do a quick center fix
            centerContainer(scrollView: scrollView)
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
        scrollView.backgroundColor = .black
        
        let containerView = UIView()
        scrollView.addSubview(containerView)
        containerView.backgroundColor = .systemGray5
        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = containerView
        
        // On next runloop, layout pages
        DispatchQueue.main.async {
            context.coordinator.layoutPages()
            context.coordinator.isInitialLoad = false
        }
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // If the pages array changed (added or removed pages),
        // re-layout everything
        context.coordinator.layoutPages()
    }
}

// A small extension to store the page's UUID as a tag reference
fileprivate extension PKCanvasView {
    private struct AssociatedKeys {
        static var tagIDKey = "tagIDKey"
    }
    
    var tagID: UUID? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.tagIDKey) as? UUID
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.tagIDKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}
