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
    
    // Binding for the template
    @Binding var template: CanvasTemplate
    
    // Configuration options
    let pageSize = CGSize(width: 612, height: 792) // Standard US Letter size (8.5" x 11" at 72 DPI)
    let pageSpacing: CGFloat = 20
    let horizontalPadding: CGFloat = 20

    // Initial number of pages - we'll grow this dynamically
    @State private var numberOfPages: Int = 2
    
    // Tool picker for PencilKit
    let toolPicker = PKToolPicker()
    
    // Coordinator to handle the scroll view and canvas interactions
    class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        var parent: PagedCanvasView
        var canvasView: PKCanvasView!
        var scrollView: UIScrollView!
        var lastUpdate = Date()
        var isInitialLoad = true
        var updateCounter = 0
        var templateLayers: [CALayer] = []
        
        // Add properties to track template changes
        var lastTemplateType: CanvasTemplate.TemplateType?
        var lastTemplateSpacing: CGFloat?
        
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
            
            // Check if we need to add a new page
            checkAndAddNewPageIfNeeded()
        }
        
        // New method to check if drawing extends to the last page and add a new page if needed
        func checkAndAddNewPageIfNeeded() {
            // Get the strokes from the drawing
            let strokes = canvasView.drawing.strokes
            
            // Calculate the bottom of the last page
            let lastPageBottom = CGFloat(parent.numberOfPages) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            
            // Check if any stroke extends below the bottom of the second-to-last page
            let secondToLastPageBottom = lastPageBottom - (parent.pageSize.height + parent.pageSpacing)
            
            for stroke in strokes {
                // Get the bounds of the stroke
                let strokeBounds = stroke.renderBounds
                
                // If the stroke extends below the second-to-last page bottom,
                // we'll add a new page
                if strokeBounds.maxY > secondToLastPageBottom {
                    // Only add a page if we're currently on the last page
                    if parent.numberOfPages <= Int(strokeBounds.maxY / (parent.pageSize.height + parent.pageSpacing)) + 1 {
                        print("📐 Drawing extends to last page, adding a new page")
                        
                        // Update the page count via the parent
                        DispatchQueue.main.async {
                            // Add one more page
                            self.parent.numberOfPages += 1
                            
                            // Update the scroll view and canvas
                            self.updateContentSizeAndDividers()
                        }
                        
                        // Break after deciding to add a page
                        break
                    }
                }
            }
        }
        
        // Method to update the content size and page dividers
        func updateContentSizeAndDividers() {
            guard let scrollView = self.scrollView, let canvasView = self.canvasView else { return }
            
            // Calculate total content height
            let totalHeight = CGFloat(parent.numberOfPages) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            
            // Update scroll view content size
            scrollView.contentSize = CGSize(width: scrollView.frame.width, height: totalHeight)
            
            // Update canvas view frame
            let canvasWidth = min(UIScreen.main.bounds.width - (parent.horizontalPadding * 2), parent.pageSize.width)
            canvasView.frame = CGRect(
                x: (scrollView.frame.width - canvasWidth) / 2,
                y: 0,
                width: canvasWidth,
                height: totalHeight
            )
            
            // Update page dividers
            parent.clearPageDividers(from: scrollView)
            parent.addPageDividers(to: scrollView, canvasWidth: canvasWidth, numberOfPages: parent.numberOfPages)
            
            // Update template rendering
            applyTemplate()
            
            print("📐 Updated content size to \(totalHeight) points tall for \(parent.numberOfPages) pages")
        }
        
        // Apply the selected template to the canvas background
        func applyTemplate() {
            // Remove existing template layers
            for layer in templateLayers {
                layer.removeFromSuperlayer()
            }
            templateLayers.removeAll()
            
            // If no template is selected, we're done
            if parent.template.type == .none {
                return
            }
            
            guard let canvasView = self.canvasView else { return }
            
            // Get template parameters
            let spacing = parent.template.spacing
            let lineWidth = parent.template.lineWidth
            let color = parent.template.color.cgColor
            
            // Draw template for each page
            for pageIndex in 0..<parent.numberOfPages {
                let pageRect = CGRect(
                    x: 0,
                    y: CGFloat(pageIndex) * (parent.pageSize.height + parent.pageSpacing),
                    width: canvasView.frame.width,
                    height: parent.pageSize.height
                )
                
                // Create a template layer for this page
                let templateLayer = CALayer()
                templateLayer.frame = pageRect
                
                switch parent.template.type {
                case .lined:
                    // Create lines
                    for y in stride(from: spacing, to: pageRect.height, by: spacing) {
                        let lineLayer = CAShapeLayer()
                        lineLayer.strokeColor = color
                        lineLayer.lineWidth = lineWidth
                        
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: pageRect.width, y: y))
                        lineLayer.path = path.cgPath
                        
                        templateLayer.addSublayer(lineLayer)
                    }
                    
                case .graph:
                    // Create horizontal lines
                    for y in stride(from: spacing, to: pageRect.height, by: spacing) {
                        let lineLayer = CAShapeLayer()
                        lineLayer.strokeColor = color
                        lineLayer.lineWidth = lineWidth
                        
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: pageRect.width, y: y))
                        lineLayer.path = path.cgPath
                        
                        templateLayer.addSublayer(lineLayer)
                    }
                    
                    // Create vertical lines
                    for x in stride(from: spacing, to: pageRect.width, by: spacing) {
                        let lineLayer = CAShapeLayer()
                        lineLayer.strokeColor = color
                        lineLayer.lineWidth = lineWidth
                        
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: pageRect.height))
                        lineLayer.path = path.cgPath
                        
                        templateLayer.addSublayer(lineLayer)
                    }
                    
                case .dotted:
                    // Create dot pattern
                    for y in stride(from: spacing, to: pageRect.height, by: spacing) {
                        for x in stride(from: spacing, to: pageRect.width, by: spacing) {
                            let dotLayer = CAShapeLayer()
                            dotLayer.fillColor = color
                            
                            let dotSize = lineWidth * 2
                            let dotRect = CGRect(
                                x: x - dotSize/2,
                                y: y - dotSize/2,
                                width: dotSize,
                                height: dotSize
                            )
                            
                            let path = UIBezierPath(ovalIn: dotRect)
                            dotLayer.path = path.cgPath
                            
                            templateLayer.addSublayer(dotLayer)
                        }
                    }
                    
                case .none:
                    break // No template
                }
                
                // Add the template layer to the view
                canvasView.layer.insertSublayer(templateLayer, at: 0)
                templateLayers.append(templateLayer)
            }
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
        
        // Create canvas view with enough height for initial pages
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .white
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 2)
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
        if UIApplication.shared.connectedScenes.first is UIWindowScene {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
        
        // Add page dividers
        addPageDividers(to: scrollView, canvasWidth: canvasWidth, numberOfPages: numberOfPages)
        
        // Load drawing after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("📐 Setting initial drawing")
            canvasView.drawing = drawing
            
            // Apply template
            context.coordinator.applyTemplate()
            
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
            clearPageDividers(from: scrollView)
            addPageDividers(to: scrollView, canvasWidth: canvasWidth, numberOfPages: numberOfPages)
        }
        
        // Apply template if it hasn't been applied yet or has changed
        let coordinator = context.coordinator
        let templateChanged = coordinator.lastTemplateType != template.type ||
                             coordinator.lastTemplateSpacing != template.spacing
        
        if templateChanged {
            coordinator.applyTemplate()
            coordinator.lastTemplateType = template.type
            coordinator.lastTemplateSpacing = template.spacing
        }
        
        context.coordinator.updateCounter += 1
    }
    
    // Method to clear existing page dividers
    func clearPageDividers(from scrollView: UIScrollView) {
        for view in scrollView.subviews where view.tag == 999 {
            view.removeFromSuperview()
        }
    }
    
    func addPageDividers(to scrollView: UIScrollView, canvasWidth: CGFloat, numberOfPages: Int) {
        // Add visual indicators for page breaks
        for i in 1..<numberOfPages {
            let yPosition = pageSize.height * CGFloat(i) + (pageSpacing * CGFloat(i - 1))
            
            // Create a container view for proper positioning
            let containerView = UIView()
            containerView.frame = CGRect(
                x: (scrollView.frame.width - canvasWidth) / 2,
                y: yPosition,
                width: canvasWidth,
                height: pageSpacing
            )
            containerView.backgroundColor = .clear
            containerView.tag = 999 // Tag for identification
            
            // Add a dashed line in the middle of the page spacing
            let lineLayer = CAShapeLayer()
            lineLayer.strokeColor = UIColor.systemGray4.cgColor
            lineLayer.lineDashPattern = [4, 4] // 4 points line, 4 points gap
            lineLayer.lineWidth = 1
            
            // Create a path for the dashed line
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: pageSpacing / 2))
            path.addLine(to: CGPoint(x: canvasWidth, y: pageSpacing / 2))
            lineLayer.path = path.cgPath
            
            // Add the dashed line to the container
            containerView.layer.addSublayer(lineLayer)
            
            // Add page number label
            let pageLabel = UILabel()
            pageLabel.text = "Page \(i + 1)"
            pageLabel.textColor = .systemGray
            pageLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            pageLabel.sizeToFit()
            pageLabel.center = CGPoint(
                x: canvasWidth / 2,
                y: pageSpacing / 2
            )
            
            // Add the label to the container
            containerView.addSubview(pageLabel)
            
            // Add the container to the scroll view
            scrollView.addSubview(containerView)
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
