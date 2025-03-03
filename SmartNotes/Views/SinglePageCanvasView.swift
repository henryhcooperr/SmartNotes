//
//  SinglePageCanvasView.swift
//  SmartNotes
//

import SwiftUI
import PencilKit

struct SinglePageCanvasView: UIViewRepresentable {
    @Binding var page: Page
    @Binding var noteTemplate: CanvasTemplate // if you want a global note template
    let pageIndex: Int
    let totalPages: Int
    
    // Called when user draws near the bottom
    var onNeedNextPage: (() -> Void)?
    
    class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        let parent: SinglePageCanvasView
        var scrollView: UIScrollView?
        var canvasView: PKCanvasView?
        var toolPicker: PKToolPicker?
        
        // Track if we've done an initial load to avoid repeated calls
        var isInitialLoad = true
        
        init(_ parent: SinglePageCanvasView) {
            self.parent = parent
        }
        
        // PKCanvasViewDelegate
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Save the page's drawing data
            DispatchQueue.main.async {
                self.parent.page.drawingData = canvasView.drawing.dataRepresentation()
            }
            
            // If we've finished initial load, check if we need next page
            if !isInitialLoad {
                checkIfNeedNextPage(drawingBounds: canvasView.drawing.bounds)
            }
        }
        
        private func checkIfNeedNextPage(drawingBounds: CGRect) {
            guard let canvasView = canvasView else { return }
            
            // Suppose the 'page height' is the canvasView's height
            let pageHeight = canvasView.frame.height
            // If user draws within 20% of bottom
            let threshold = pageHeight * 0.8
            
            if drawingBounds.maxY > threshold {
                // Call parent's closure to request a new page
                print("✏️ Page \(parent.pageIndex + 1) near bottom. Requesting next page...")
                parent.onNeedNextPage?()
            }
        }
        
        // UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return canvasView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerCanvas(scrollView: scrollView)
            
            // Update quality based on zoom level
            if let canvasView = canvasView {
                // For high zoom levels, increase rendering quality
                if scrollView.zoomScale > 2.0 {
                    canvasView.layer.contentsScale = UIScreen.main.scale * 2.0
                    canvasView.setNeedsDisplay()
                } else {
                    canvasView.layer.contentsScale = UIScreen.main.scale
                    canvasView.setNeedsDisplay()
                }
            }
        }
        
        private func centerCanvas(scrollView: UIScrollView) {
            guard let canvasView = canvasView else { return }
            
            let offsetX = max((scrollView.bounds.width - canvasView.frame.width * scrollView.zoomScale) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - canvasView.frame.height * scrollView.zoomScale) * 0.5, 0)
            
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // 1) Create a scroll view that allows pinch to zoom
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 0.25  // Allow zooming out further
        scrollView.maximumZoomScale = 5.0   // Increase max zoom for detailed work
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.bouncesZoom = true
        
        // 2) Create the PKCanvasView
        let canvasView = PKCanvasView()
        canvasView.drawing = PKDrawing.fromData(page.drawingData)
        canvasView.delegate = context.coordinator
        canvasView.alwaysBounceVertical = false
        canvasView.backgroundColor = .white
        
        // Configure for high-resolution rendering
        canvasView.layer.contentsScale = UIScreen.main.scale
        if let window = UIApplication.shared.windows.first {
            canvasView.layer.contentsScale = window.screen.scale
        }
        
        // If iOS 16 or above:
        if #available(iOS 16.0, *) {
            canvasView.drawingPolicy = .anyInput
        } else {
            canvasView.allowsFingerDrawing = true
        }
        
        // 3) Set a fixed frame for the canvas matching "a single page"
        //    This might be ~8.5" x 11" at 72 dpi = 612 x 792
        //    or you can go bigger, e.g. 1000 points tall to have extra space.
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        
        canvasView.frame = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        // 4) Add the canvas as a subview of the scrollView
        scrollView.addSubview(canvasView)
        scrollView.contentSize = canvasView.frame.size
        
        // 5) Tool picker
        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }
        
        context.coordinator.scrollView = scrollView
        context.coordinator.canvasView = canvasView
        
        // 6) Mark initial load done after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            context.coordinator.isInitialLoad = false
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // 1) If page drawing changed externally, update the canvas
        if let canvasView = context.coordinator.canvasView {
            let currentData = canvasView.drawing.dataRepresentation()
            if currentData != page.drawingData {
                canvasView.drawing = PKDrawing.fromData(page.drawingData)
            }
        }
        
        TemplateRenderer.applyTemplateToCanvas(
                    canvasView,
                    template: noteTemplate,
                    pageSize: CGSize(width: 612, height: 792),  // or your dynamic size
                    numberOfPages: 1,
                    pageSpacing: 0
                )
    }
}
