//
//  PagedCanvasView.swift
//  SmartNotes
//
//  Created on 2/25/25.
//
//  This file implements a multi-page scrollable canvas.
//  Key responsibilities:
//    - Creating a scrollable area for drawing across multiple pages
//    - Managing page boundaries with visual indicators
//    - Applying templates to each page
//    - Automatically extending when drawing reaches page bottom
//    - Handling PencilKit tool picker integration
//
//  This is an alternative implementation to SafeCanvasView in
//  TemplateCanvasView.swift.
//

import SwiftUI
import PencilKit
import UIKit

struct PagedCanvasView: UIViewRepresentable {
    // Binding to store the PKDrawing
    @Binding var drawing: PKDrawing
    
    // Binding for the template
    @Binding var template: CanvasTemplate
    
    // Binding for number of pages
    @Binding var numberOfPages: Int
    
    // Configuration options
    let pageSize: CGSize // Standard US Letter size (8.5" x 11" at 72 DPI)
    let pageSpacing: CGFloat
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
        var updateCounter = 0
        
        var lastTemplateType: CanvasTemplate.TemplateType?
        var lastTemplateSpacing: CGFloat?
        var lastTemplateLineWidth: CGFloat?
        var lastTemplateColorHex: String?
        
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
            
            // Debounce updates - reduced from 0.3s to 0.1s for more responsive page additions
            let now = Date()
            if now.timeIntervalSince(lastUpdate) < 0.1 {
                return // Skip rapid updates
            }
            
            lastUpdate = now
            print("📐 Canvas drawing changed")
            
            // Update the binding
            parent.drawing = canvasView.drawing
            
            // Check if we need to add a new page - do this on every drawing change
            checkAndAddNewPageIfNeeded()
        }
        
        // Completely revised method to check if drawing extends to the last page
        func checkAndAddNewPageIfNeeded() {
            // Get the bounds of the entire drawing
            let drawingBounds = canvasView.drawing.bounds
            print("📐 Drawing bounds: \(drawingBounds)")
            
            // Calculate the bottom of the last page
            let pageHeight = parent.pageSize.height
            let pageSpacing = parent.pageSpacing
            let lastPageBottom = CGFloat(parent.numberOfPages) * pageHeight +
                                CGFloat(parent.numberOfPages - 1) * pageSpacing
            
            print("📐 Last page bottom: \(lastPageBottom), Drawing maxY: \(drawingBounds.maxY)")
            
            // Calculate how close to the bottom we want to trigger a new page (80% of page height)
            let triggerThreshold = lastPageBottom - (pageHeight * 0.2)
            
            // If the drawing extends beyond the trigger threshold
            if drawingBounds.maxY > triggerThreshold {
                print("📐 Drawing extends near last page bottom, adding a new page")
                
                // Update the page count via the parent
                DispatchQueue.main.async {
                    // Add one more page
                    self.parent.numberOfPages += 1
                    print("📐 New page count: \(self.parent.numberOfPages)")
                    
                    // Update the scroll view and canvas
                    self.updateContentSizeAndDividers()
                    
                    // Scroll to show part of the new page
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let scrollView = self.scrollView {
                            // Scroll to show the top portion of the new page
                            let newPageTop = lastPageBottom + self.parent.pageSpacing
                            let newContentOffset = CGPoint(x: 0, y: newPageTop - (scrollView.frame.height * 0.7))
                            scrollView.setContentOffset(newContentOffset, animated: true)
                        }
                    }
                }
            }
        }
        
        // Method to update the content size and page dividers
        func updateContentSizeAndDividers() {
            guard let scrollView = self.scrollView, let canvasView = self.canvasView else {
                print("📐 Error: Missing scrollView or canvasView")
                return
            }
            
            // Calculate total content height
            let totalHeight = CGFloat(parent.numberOfPages) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            print("📐 Updating content size to height: \(totalHeight)")
            
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
        }
        
        // Apply the selected template to the canvas background
        func applyTemplate() {
            // Use the TemplateRenderer to render the template directly to the canvas
            TemplateRenderer.applyTemplateToCanvas(
                canvasView,
                template: parent.template,
                pageSize: parent.pageSize,
                numberOfPages: parent.numberOfPages,
                pageSpacing: parent.pageSpacing
            )
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
    
    // Inside the updateUIView method of PagedCanvasView, replace the sizing code with:

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        
        // Only proceed if we have valid dimensions
        if scrollView.frame.width <= 0 {
            print("⚠️ PagedCanvasView: Invalid scrollView width (\(scrollView.frame.width)), skipping update")
            return
        }
        
        // Only update drawing when necessary to avoid loops
        if !coordinator.isInitialLoad && coordinator.canvasView.drawing != drawing {
            print("📐 Updating canvas drawing from binding")
            coordinator.canvasView.drawing = drawing
        }
        
        // Calculate reasonable content size
        let defaultPageHeight = pageSize.height + pageSpacing
        let totalPageHeight = CGFloat(numberOfPages) * defaultPageHeight - pageSpacing
        let safeHeight = min(max(totalPageHeight, pageSize.height), 10000) // Ensure reasonable bounds
        
        print("📐 Calculating content size: \(scrollView.frame.width) x \(safeHeight)")
        
        // Safely update scroll view content size
        let contentSize = CGSize(width: scrollView.frame.width, height: safeHeight)
        if !contentSize.width.isNaN && !contentSize.height.isNaN &&
           contentSize.width > 0 && contentSize.height > 0 &&
           contentSize.width < 5000 && contentSize.height < 15000 {
            scrollView.contentSize = contentSize
        } else {
            print("⚠️ PagedCanvasView: Invalid content size calculated: \(contentSize)")
        }
        
        // Update canvas size safely
        let canvasWidth = min(scrollView.frame.width, pageSize.width) // Remove the horizontal padding
        
        // Calculate safe canvas frame
        let canvasFrame = CGRect(
            x: max((scrollView.frame.width - canvasWidth) / 2, 0),
            y: 0,
            width: canvasWidth,
            height: safeHeight
        )
        
        // Only apply if frame is valid
        if !canvasFrame.origin.x.isNaN && !canvasFrame.origin.y.isNaN &&
           !canvasFrame.size.width.isNaN && !canvasFrame.size.height.isNaN &&
           canvasFrame.size.width > 0 && canvasFrame.size.height > 0 {
            coordinator.canvasView.frame = canvasFrame
        } else {
            print("⚠️ PagedCanvasView: Invalid canvas frame calculated: \(canvasFrame)")
        }
        
        // Only update page dividers occasionally to improve performance
        if coordinator.updateCounter % 5 == 0 {
            // Clear and re-add page dividers
            clearPageDividers(from: scrollView)
            addPageDividers(to: scrollView, canvasWidth: canvasWidth, numberOfPages: numberOfPages)
        }
        
        // Handle template changes or first render
        if template.type != coordinator.lastTemplateType ||
           template.spacing != coordinator.lastTemplateSpacing ||
           template.lineWidth != coordinator.lastTemplateLineWidth ||
           template.colorHex != coordinator.lastTemplateColorHex ||
           coordinator.updateCounter == 0 {
            
            print("📐 Template changed or first render - applying template \(template.type.rawValue)")
            
            // Use our template renderer
            TemplateRenderer.applyTemplateToCanvas(
                coordinator.canvasView,
                template: template,
                pageSize: pageSize,
                numberOfPages: numberOfPages,
                pageSpacing: pageSpacing
            )
            
            // Update stored values
            coordinator.lastTemplateType = template.type
            coordinator.lastTemplateSpacing = template.spacing
            coordinator.lastTemplateLineWidth = template.lineWidth
            coordinator.lastTemplateColorHex = template.colorHex
        }
        
        coordinator.updateCounter += 1
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


// MARK: - Previews
#if DEBUG
struct PagedCanvasView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with explicit environment configuration
            NavigationView {
                PreviewWrapper(templateType: .graph)
            }
            .previewDisplayName("Graph Template")
            .frame(width: 800, height: 600)
            
            // Preview showing the split layout issue
            PreviewWrapper(templateType: .lined)
                .previewLayout(.fixed(width: 800, height: 600))
                .previewDisplayName("Layout Debug")
        }
    }
    
    private struct PreviewWrapper: View {
        let templateType: CanvasTemplate.TemplateType
        
        // State variables required for PagedCanvasView bindings
        @State private var drawing = PKDrawing()
        @State private var template: CanvasTemplate
        @State private var numberOfPages = 2
        
        init(templateType: CanvasTemplate.TemplateType) {
            self.templateType = templateType
            
            // Configure the appropriate template based on type
            var initialTemplate: CanvasTemplate
            switch templateType {
            case .lined:
                initialTemplate = .lined
            case .graph:
                initialTemplate = .graph
            case .dotted:
                initialTemplate = .dotted
            case .none:
                initialTemplate = .none
            }
            
            // Initialize the template State
            _template = State(initialValue: initialTemplate)
        }
        
        var body: some View {
            VStack(spacing: 0) {
                Text("Template Type: \(templateType.rawValue)")
                    .font(.headline)
                    .padding()
                    .background(Color.yellow.opacity(0.3))
                
                ZStack {
                    // Background color to show boundaries
                    Color.white
                    
                    // The actual canvas view
                    PagedCanvasView(
                        drawing: $drawing,
                        template: $template,
                        numberOfPages: $numberOfPages,
                        pageSize: CGSize(width: 612, height: 792),
                        pageSpacing: 20
                    )
                    .border(Color.blue, width: 1) // Show canvas bounds
                }
                .background(Color.gray.opacity(0.1)) // Show outer container bounds
                .padding(.horizontal)
                
                // Debug controls
                HStack {
                    Button("Force Template") {
                        // Force template refresh
                        let current = template
                        template = .none
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            template = current
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    // Show current page count
                    Text("\(numberOfPages) pages")
                        .font(.caption)
                }
                .padding()
            }
        }
    }
}
#endif
