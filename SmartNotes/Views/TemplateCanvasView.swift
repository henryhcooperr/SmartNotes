//
//  TemplateCanvasView.swift
//  SmartNotes
//
//  Created on 2/26/25.
//

import SwiftUI
import PencilKit

struct TemplateCanvasView: View {
    @Binding var drawing: PKDrawing
    @State private var showingTemplateSettings = false
    @State private var template: CanvasTemplate = .none
    @State private var isInitialRenderComplete = false
    @State private var numberOfPages: Int = 2
    
    // Properly associate template with the specific note
    var noteID: UUID
    private var templateKey: String {
        "note.template.\(noteID.uuidString)"  // Make key unique per note
    }
    
    var body: some View {
        SafeCanvasView(
            drawing: $drawing,
            template: $template,
            numberOfPages: $numberOfPages
        )
        .sheet(isPresented: $showingTemplateSettings) {
            TemplateSettingsView(template: $template)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTemplateSettings"))) { _ in
            showingTemplateSettings = true
        }
        // Add listener for forcing tool picker visibility
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceToolPickerVisible"))) { _ in
            print("📝 Forcing tool picker to appear")
            // This will be handled by SafeCanvasView
            NotificationCenter.default.post(
                name: NSNotification.Name("CanvasForceFirstResponder"),
                object: nil
            )
        }
        .onAppear {
            print("📝 TemplateCanvasView appeared for note: \(noteID.uuidString)")
            
            // Load template from UserDefaults with note-specific key
            if let savedData = UserDefaults.standard.data(forKey: templateKey) {
                do {
                    let savedTemplate = try JSONDecoder().decode(CanvasTemplate.self, from: savedData)
                    print("📝 Loaded template: \(savedTemplate.type.rawValue)")
                    
                    // Important: Delay setting to ensure view is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        template = savedTemplate
                        isInitialRenderComplete = true
                    }
                } catch {
                    print("📝 Error loading template: \(error)")
                    isInitialRenderComplete = true
                }
            } else {
                // No saved template - mark as ready
                isInitialRenderComplete = true
            }
        }
        .onChange(of: template) { oldTemplate, newTemplate in
            // Only save if initial render is complete (prevents overwrites during setup)
            if isInitialRenderComplete {
                do {
                    let data = try JSONEncoder().encode(newTemplate)
                    UserDefaults.standard.set(data, forKey: templateKey)
                    print("📝 Saved template: \(newTemplate.type.rawValue) for note: \(noteID.uuidString)")
                } catch {
                    print("📝 Error saving template: \(error)")
                }
            }
        }
    }
    
    // Default initializer for compatibility with existing code
    init(drawing: Binding<PKDrawing>) {
        self._drawing = drawing
        self.noteID = UUID() // Use a default ID if none provided
    }
    
    // Initializer with note ID parameter
    init(drawing: Binding<PKDrawing>, noteID: UUID) {
        self._drawing = drawing
        self.noteID = noteID
    }
}

/// A completely revised canvas view that supports zooming and better page detection
struct SafeCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var template: CanvasTemplate
    @Binding var numberOfPages: Int
    
    // Standard dimensions for US Letter paper (8.5" x 11")
    private let pageWidth: CGFloat = 612 // 8.5" at 72 DPI
    private let pageHeight: CGFloat = 792 // 11" at 72 DPI
    private let pageSpacing: CGFloat = 20
    
    class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        var parent: SafeCanvasView
        var canvasView: PKCanvasView?
        var mainScrollView: UIScrollView?
        var isInitialLoad = true
        var lastTemplate: CanvasTemplate?
        var toolPicker: PKToolPicker?
        var dividerViews: [UIView] = []
        
        init(_ parent: SafeCanvasView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Skip updates during initial load
            if isInitialLoad {
                print("📐 Drawing changed (during initialization, ignored)")
                return
            }
            
            // Update the binding
            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
                
                // Check if we need to add a new page - do this on every drawing change
                self.checkAndAddNewPageIfNeeded()
            }
        }
        
        // Completely revised method to check if drawing extends to the last page
        func checkAndAddNewPageIfNeeded() {
            guard let canvasView = canvasView else { return }
            
            // Get the bounds of the entire drawing
            let drawingBounds = canvasView.drawing.bounds
            print("📐 Drawing bounds: \(drawingBounds)")
            
            // Calculate the bottom of the last page
            let pageHeight = parent.pageHeight
            let pageSpacing = parent.pageSpacing
            let lastPageBottom = CGFloat(parent.numberOfPages) * pageHeight +
                                CGFloat(parent.numberOfPages - 1) * pageSpacing
            
            print("📐 Last page bottom: \(lastPageBottom), Drawing maxY: \(drawingBounds.maxY)")
            
            // Calculate how close to the bottom we want to trigger a new page (80% of page height)
            let triggerThreshold = lastPageBottom - (pageHeight * 0.3)
            
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
                        if let scrollView = self.mainScrollView {
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
            guard let scrollView = self.mainScrollView,
                  let canvasView = self.canvasView else {
                print("📐 Error: Missing scrollView or canvasView")
                return
            }
            
            // Calculate total content height
            let totalHeight = CGFloat(parent.numberOfPages) * (parent.pageHeight + parent.pageSpacing) - parent.pageSpacing
            print("📐 Updating content size to height: \(totalHeight)")
            
            // Calculate the proper width based on the aspect ratio
            // This maintains the 8.5" x 11" ratio while ensuring it fits within the screen
            let availableWidth = scrollView.frame.width
            let maxCanvasWidth = min(availableWidth, parent.pageWidth)
            
            // Update canvas view frame - now with proper aspect ratio
            let newCanvasFrame = CGRect(
                x: (availableWidth - maxCanvasWidth) / 2, // Center horizontally
                y: 0,
                width: maxCanvasWidth,
                height: totalHeight
            )
            
            // Only apply if frame is valid
            if newCanvasFrame.size.width > 0, newCanvasFrame.size.height > 0 {
                canvasView.frame = newCanvasFrame
            }
            
            // Update scroll view content size
            scrollView.contentSize = CGSize(width: availableWidth, height: totalHeight)
            
            // Redraw page dividers
            updatePageDividers()
            
            // Apply template
            applyTemplate()
        }
        
        // New method to update page dividers that works better with zooming
        func updatePageDividers() {
            guard let scrollView = self.mainScrollView,
                  let canvasView = self.canvasView else { return }
            
            // Remove existing dividers
            for dividerView in dividerViews {
                dividerView.removeFromSuperview()
            }
            dividerViews.removeAll()
            
            // Don't add dividers during initial load
            if isInitialLoad { return }
            
            // Calculate scale-independent page dimensions
            let canvasWidth = canvasView.frame.width
            let zoomScale = scrollView.zoomScale
            
            // Add visual indicators for page breaks
            for i in 1..<parent.numberOfPages {
                let yPosition = (parent.pageHeight * CGFloat(i) + parent.pageSpacing * CGFloat(i - 1)) * zoomScale
                
                // Create a container for the page divider elements
                let dividerView = UIView()
                dividerView.frame = CGRect(
                    x: 0,
                    y: yPosition,
                    width: canvasWidth,
                    height: parent.pageSpacing * zoomScale
                )
                dividerView.backgroundColor = .clear
                dividerView.tag = 999 // Tag for identification
                
                // Add a dashed line in the middle of the page spacing
                let lineLayer = CAShapeLayer()
                lineLayer.strokeColor = UIColor.systemGray4.cgColor
                lineLayer.lineDashPattern = [4, 4] // 4 points line, 4 points gap
                lineLayer.lineWidth = 1
                
                // Create a path for the dashed line
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: (parent.pageSpacing * zoomScale) / 2))
                path.addLine(to: CGPoint(x: canvasWidth, y: (parent.pageSpacing * zoomScale) / 2))
                lineLayer.path = path.cgPath
                
                // Add the dashed line to the container
                dividerView.layer.addSublayer(lineLayer)
                
                // Add page number label
                let pageLabel = UILabel()
                pageLabel.text = "Page \(i + 1)"
                pageLabel.textColor = .systemGray
                pageLabel.font = UIFont.systemFont(ofSize: 12 * zoomScale, weight: .medium)
                pageLabel.sizeToFit()
                pageLabel.center = CGPoint(
                    x: canvasWidth / 2,
                    y: (parent.pageSpacing * zoomScale) / 2
                )
                
                // Add the label to the container
                dividerView.addSubview(pageLabel)
                
                // Add the container to the canvas instead of scroll view
                canvasView.addSubview(dividerView)
                dividerViews.append(dividerView)
            }
        }
        
        func applyTemplate() {
            guard let canvasView = canvasView else { return }
            
            // Always apply template regardless of lastTemplate state
            print("🖌️ Forcing template application: \(parent.template.type.rawValue)")
            
            TemplateRenderer.applyTemplateToCanvas(
                canvasView,
                template: parent.template,
                pageSize: CGSize(width: parent.pageWidth, height: parent.pageHeight),
                numberOfPages: parent.numberOfPages,
                pageSpacing: parent.pageSpacing
            )
            
            lastTemplate = parent.template
        }
        
        // Ensure tool picker is visible
        func ensureToolPickerVisible() {
            guard let canvasView = canvasView else { return }
            
            // Create tool picker if needed
            if toolPicker == nil {
                toolPicker = PKToolPicker()
            }
            
            guard let toolPicker = toolPicker else { return }
            
            print("🔧 Ensuring tool picker is visible")
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            
            // Make canvas first responder to show the tool picker
            if !canvasView.isFirstResponder {
                print("🔧 Canvas is not first responder - making it first responder")
                canvasView.becomeFirstResponder()
            }
        }
        
        // UIScrollViewDelegate method to provide zoom view
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return canvasView
        }
        
        // Handle zoom scale changes
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Center the zooming canvas if smaller than the scroll view frame
            centerZoomingView(in: scrollView)
            
            // Update page dividers when zoom changes
            updatePageDividers()
        }
        
        // Center the zooming canvas
        private func centerZoomingView(in scrollView: UIScrollView) {
            guard let canvasView = canvasView else { return }
            
            let offsetX = max((scrollView.bounds.width - canvasView.frame.width * scrollView.zoomScale) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - canvasView.frame.height * scrollView.zoomScale) * 0.5, 0)
            
            scrollView.contentInset = UIEdgeInsets(
                top: offsetY,
                left: offsetX,
                bottom: offsetY,
                right: offsetX
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // Create main scroll view with zoom support
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .systemBackground
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.bouncesZoom = true
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.contentInsetAdjustmentBehavior = .automatic
        context.coordinator.mainScrollView = scrollView
        
        // Create the canvas view to fill the available space
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.alwaysBounceVertical = true
        canvasView.allowsFingerDrawing = true  // Allow finger drawing explicitly
        context.coordinator.canvasView = canvasView
        
        // Calculate initial content height
        let totalHeight = CGFloat(numberOfPages) * (pageHeight + pageSpacing) - pageSpacing
        
        // Calculate the width that maintains the proper aspect ratio
        let availableWidth = scrollView.frame.width > 0 ? scrollView.frame.width : UIScreen.main.bounds.width
        let canvasWidth = min(availableWidth, pageWidth)
        
        // Set canvas view with proper aspect ratio
        canvasView.frame = CGRect(
            x: (availableWidth - canvasWidth) / 2, // Center horizontally
            y: 0,
            width: canvasWidth,
            height: totalHeight
        )
        
        // Set up the tool picker
        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        
        // Add the canvas view to the scroll view
        scrollView.addSubview(canvasView)
        scrollView.contentSize = CGSize(width: availableWidth, height: totalHeight)
        
        // Load drawing after a slight delay to allow view setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            canvasView.drawing = drawing
            
            // Make canvas first responder AFTER drawing is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                toolPicker.setVisible(true, forFirstResponder: canvasView)
                canvasView.becomeFirstResponder()
                
                // Update content size and apply template
                context.coordinator.updateContentSizeAndDividers()
                
                context.coordinator.isInitialLoad = false
                print("📝 Canvas ready with tool picker visible")
            }
        }
        
        // Add observation for forced tool picker visibility
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CanvasForceFirstResponder"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔧 Forcing tool picker visibility from notification")
            context.coordinator.ensureToolPickerVisible()
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let canvasView = context.coordinator.canvasView else { return }
        
        // Only proceed if the scroll view has a valid frame
        guard scrollView.frame.width > 0, scrollView.frame.height > 0 else {
            print("⚠️ SafeCanvasView: Invalid scrollView dimensions: \(scrollView.frame.size)")
            return
        }
        
        // Update drawing if needed
        if !context.coordinator.isInitialLoad, canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }
        
        // Make sure canvasView is still first responder periodically
        if !context.coordinator.isInitialLoad && !canvasView.isFirstResponder {
            context.coordinator.ensureToolPickerVisible()
        }
        
        // Update the dividers if the view resizes
        context.coordinator.updatePageDividers()
    }
}

// MARK: - Preview
#if DEBUG
struct TemplateCanvasView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TemplateCanvasView(drawing: .constant(PKDrawing()), noteID: UUID())
                .navigationTitle("Template Preview")
        }
    }
}
#endif
