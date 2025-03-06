//
//  SinglePageCanvasView.swift
//  SmartNotes
//

import SwiftUI
import PencilKit
import Foundation

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
        
        // Store the last template type to avoid unnecessary reapplications
        var lastTemplateType: CanvasTemplate.TemplateType?
        
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
            
            // Update quality based on zoom level using CanvasManager
            if let canvasView = canvasView {
                CanvasManager.shared.adjustQualityForZoom(canvasView, zoomScale: scrollView.zoomScale)
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
        print("🖋️ Creating new SinglePageCanvasView")
        
        // 1) Create a scroll view that allows pinch to zoom
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = GlobalSettings.minimumZoomScale
        scrollView.maximumZoomScale = GlobalSettings.maximumZoomScale
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.bouncesZoom = true
        
        // 2) Create the PKCanvasView using CanvasManager
        let canvasView = CanvasManager.shared.createCanvas(withID: page.id, initialDrawing: page.drawingData)
        canvasView.delegate = context.coordinator
        
        // 3) Set a fixed frame for the canvas matching "a single page"
        // Use the scaled page size from GlobalSettings
        canvasView.frame = CGRect(x: 0, y: 0, width: GlobalSettings.scaledPageSize.width, height: GlobalSettings.scaledPageSize.height)
        
        // 4) Add the canvas as a subview of the scrollView
        scrollView.addSubview(canvasView)
        scrollView.contentSize = canvasView.frame.size
        
        // Set initial zoom scale to maintain the same view size
        scrollView.zoomScale = GlobalSettings.defaultZoomScale
        
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
        
        // Apply the template immediately using CanvasManager
        print("🖋️ Initial template application of type: \(noteTemplate.type.rawValue)")
        CanvasManager.shared.applyTemplate(
            to: canvasView,
            template: noteTemplate,
            pageSize: GlobalSettings.scaledPageSize
        )
        
        // Store the initial template type
        context.coordinator.lastTemplateType = noteTemplate.type
        
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
            
            // Check if template has changed and apply it if needed
            if context.coordinator.lastTemplateType != noteTemplate.type {
                print("🖋️ Template changed from \(context.coordinator.lastTemplateType?.rawValue ?? "nil") to \(noteTemplate.type.rawValue), reapplying")
                
                // Apply the new template using CanvasManager
                CanvasManager.shared.applyTemplate(
                    to: canvasView,
                    template: noteTemplate,
                    pageSize: GlobalSettings.scaledPageSize
                )
                
                // Update the stored template type
                context.coordinator.lastTemplateType = noteTemplate.type
            } else if GlobalSettings.debugModeEnabled {
                // In debug mode, refresh template on every update to ensure it's visible
                print("🐞 Debug mode: Refreshing template on update")
                CanvasManager.shared.applyTemplate(
                    to: canvasView,
                    template: noteTemplate,
                    pageSize: GlobalSettings.scaledPageSize
                )
            }
        }
    }
}
