//
//  PagedCanvasView.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI
import PencilKit
import UIKit

struct PagedCanvasView: UIViewRepresentable {
    // Binding to store the PKDrawing
    @Binding var drawing: PKDrawing
    
    // Configuration options
    let pageSize = CGSize(width: 612, height: 792) // Standard US Letter size (8.5" x 11" at 72 DPI)
    let pageSpacing: CGFloat = 20
    let numberOfPages: Int = 3 // Reduced from 5 to improve performance
    let horizontalPadding: CGFloat = 20
    
    // Tool picker for PencilKit
    let toolPicker = PKToolPicker()
    
    // Coordinator to handle the scroll view and canvas interactions
    class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        var parent: PagedCanvasView
        var canvasView: PKCanvasView!
        var scrollView: UIScrollView!
        var lastUpdate = Date()
        var isInitialLoad = true
        var updateCounter = 0 // Moved from struct to coordinator
        
        init(parent: PagedCanvasView) {
            self.parent = parent
            print("📐 PagedCanvasView Coordinator initialized")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Prevent scrolling above the top boundary
            if scrollView.contentOffset.y < 0 {
                scrollView.contentOffset.y = 0
            }
        }
        
        // Implement PKCanvasViewDelegate to detect changes to the drawing
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Skip updates during initial load
            if isInitialLoad {
                print("📐 Drawing changed (during initialization, ignored)")
                return
            }
            
            // Debounce updates
            let now = Date()
            if now.timeIntervalSince(lastUpdate) < 0.3 {
                return // Skip rapid updates
            }
            
            lastUpdate = now
            print("📐 Canvas drawing changed")
            
            // Update the binding
            parent.drawing = canvasView.drawing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        print("📐 PagedCanvasView makeUIView called")
        
        // Create scroll view
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = UIColor(Color(.systemGroupedBackground))
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        scrollView.alwaysBounceVertical = true
        context.coordinator.scrollView = scrollView
        
        // Create canvas view with enough height for all pages
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .white
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 2)
        canvasView.allowsFingerDrawing = true
        canvasView.delegate = context.coordinator
        context.coordinator.canvasView = canvasView
        
        // Calculate total content height
        let totalHeight = CGFloat(numberOfPages) * (pageSize.height + pageSpacing) - pageSpacing
        
        // Set canvas view frame
        let canvasWidth = min(UIScreen.main.bounds.width - (horizontalPadding * 2), pageSize.width)
        canvasView.frame = CGRect(
            x: (scrollView.frame.width - canvasWidth) / 2,
            y: 0,
            width: canvasWidth,
            height: totalHeight
        )
        
        // Set scroll view content size
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: totalHeight)
        
        // Add canvas view to scroll view
        scrollView.addSubview(canvasView)
        
        // Show the tool picker using the modern scene API
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
        
        // Add page dividers
        addPageDividers(to: scrollView, canvasWidth: canvasWidth)
        
        // Load drawing after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("📐 Setting initial drawing")
            canvasView.drawing = drawing
            
            // Mark initialization as complete after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                context.coordinator.isInitialLoad = false
                print("📐 Canvas ready for drawing changes")
            }
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Only update when necessary to avoid loops
        if !context.coordinator.isInitialLoad &&
           context.coordinator.canvasView.drawing != drawing {
            print("📐 Updating canvas drawing from binding")
            context.coordinator.canvasView.drawing = drawing
        }
        
        // Recalculate scroll view content size
        let totalHeight = CGFloat(numberOfPages) * (pageSize.height + pageSpacing) - pageSpacing
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: totalHeight)
        
        // Update canvas size
        let canvasWidth = min(UIScreen.main.bounds.width - (horizontalPadding * 2), pageSize.width)
        context.coordinator.canvasView.frame = CGRect(
            x: (scrollView.frame.width - canvasWidth) / 2,
            y: 0,
            width: canvasWidth,
            height: totalHeight
        )
        
        // Only update page dividers occasionally to improve performance
        if context.coordinator.updateCounter % 5 == 0 {
            // Clear and re-add page dividers
            for view in scrollView.subviews where view is UIView && view.tag == 999 {
                view.removeFromSuperview()
            }
            addPageDividers(to: scrollView, canvasWidth: canvasWidth)
        }
        context.coordinator.updateCounter += 1
    }
    
    private func addPageDividers(to scrollView: UIScrollView, canvasWidth: CGFloat) {
        // Add visual indicators for page breaks
        for i in 1..<numberOfPages {
            let yPosition = pageSize.height * CGFloat(i) + (pageSpacing * CGFloat(i - 1))
            
            // Add a line to indicate page break
            let lineView = UIView()
            lineView.backgroundColor = UIColor.systemGray5
            lineView.frame = CGRect(
                x: (scrollView.frame.width - canvasWidth) / 2,
                y: yPosition,
                width: canvasWidth,
                height: pageSpacing
            )
            lineView.tag = 999 // Tag for identification
            
            // Add page number label
            let pageLabel = UILabel()
            pageLabel.text = "Page \(i + 1)"
            pageLabel.textColor = .systemGray
            pageLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            pageLabel.sizeToFit()
            pageLabel.center = CGPoint(
                x: scrollView.frame.width / 2,
                y: yPosition + pageSpacing / 2
            )
            pageLabel.tag = 999 // Tag for identification
            
            scrollView.addSubview(lineView)
            scrollView.addSubview(pageLabel)
        }
    }
    
    // Helper to get page rects for PDF export
    func getPageRects() -> [CGRect] {
        var rects: [CGRect] = []
        let canvasWidth = min(UIScreen.main.bounds.width - (horizontalPadding * 2), pageSize.width)
        
        for i in 0..<numberOfPages {
            let yPosition = pageSize.height * CGFloat(i) + (pageSpacing * CGFloat(i))
            let rect = CGRect(
                x: 0,
                y: yPosition,
                width: canvasWidth,
                height: pageSize.height
            )
            rects.append(rect)
        }
        
        return rects
    }
}
