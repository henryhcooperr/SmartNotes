//
//  TemplateCanvasView.swift
//  SmartNotes
//
//  Created on 2/26/25.
//
//  This file provides the drawing canvas with template support.
//  Key responsibilities:
//    - Wrapping PKCanvasView (Apple's PencilKit canvas) in SwiftUI
//    - Loading and applying templates to the canvas background
//    - Saving template settings per note
//    - Supporting zooming and scrolling
//    - Auto-extending pages when drawing nears the bottom
//    - Handling tool picker visibility
//
//  This is the core drawing component used by NoteDetailView.
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
            // This onDismiss closure will be called when the sheet is dismissed
            // Force refresh template when sheet closes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshTemplate"),
                    object: nil
                )
            }
        } content: {
            TemplateSettingsView(template: $template)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTemplateSettings"))) { _ in
            showingTemplateSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTemplate"))) { _ in
            // Force reapplication of template when RefreshTemplate notification is received
            print("📝 Refreshing template from notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("ForceApplyTemplate"),
                object: nil,
                userInfo: ["template": template]
            )
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
                        
                        // Force template refresh after loading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("RefreshTemplate"),
                                object: nil
                            )
                        }
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
                    
                    // Force template refresh whenever template changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RefreshTemplate"),
                            object: nil
                        )
                    }
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
    
    // Standard dimensions
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
        // Observer tokens
        var templateObserver: NSObjectProtocol?
        var toolPickerObserver: NSObjectProtocol?
        
        init(_ parent: SafeCanvasView) {
            self.parent = parent
            super.init()
            
            // Set up notification observers
            self.templateObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ForceApplyTemplate"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                print("🖌️ Force apply template notification received")
                DispatchQueue.main.async {
                    self?.applyTemplate()
                }
            }
            
            self.toolPickerObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CanvasForceFirstResponder"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                print("🔧 Forcing tool picker visibility from notification")
                DispatchQueue.main.async {
                    self?.ensureToolPickerVisible()
                }
            }
        }
        
        deinit {
            // Clean up observers
            if let observer = templateObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = toolPickerObserver {
                NotificationCenter.default.removeObserver(observer)
            }
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
            
            // Update canvas view frame - expanded to fill full width
            let canvasWidth = scrollView.frame.width // Use full scroll view width
            
            // Get current zoomScale to preserve zoom
            let currentZoomScale = scrollView.zoomScale
            
            // Update canvas frame accounting for zoom
            let newCanvasFrame = CGRect(
                x: 0,
                y: 0,
                width: canvasWidth,
                height: totalHeight
            )
            
            // Only apply if frame is valid
            if newCanvasFrame.size.width > 0, newCanvasFrame.size.height > 0 {
                canvasView.frame = newCanvasFrame
            }
            
            // Update scroll view content size
            scrollView.contentSize = CGSize(width: canvasWidth, height: totalHeight)
            
            // Redraw page dividers
            parent.clearPageDividers(from: scrollView)
            parent.addPageDividers(to: scrollView, canvasWidth: canvasWidth, numberOfPages: parent.numberOfPages)
            
            // Apply template
            applyTemplate()
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
        }
        
        // Support for handling mouse wheel events
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            print("📐 Scroll view began dragging")
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
        
        // Enable mouse wheel scrolling support
        scrollView.panGestureRecognizer.allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber,
                                                           UITouch.TouchType.indirect.rawValue as NSNumber]
        scrollView.isScrollEnabled = true
        
        context.coordinator.mainScrollView = scrollView
        
        // Create the canvas view to fill the available space
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.alwaysBounceVertical = true
        // Drawing policy is already set to .anyInput which allows both finger and pencil input

        
        // Configure touch handling for the canvas
        // PKCanvasView doesn't have allowedTouchTypes property
        // Instead we'll make sure the canvas responds to all input types
        canvasView.drawingPolicy = .anyInput
        
        context.coordinator.canvasView = canvasView
        
        // Calculate initial content height
        let totalHeight = CGFloat(numberOfPages) * (pageHeight + pageSpacing) - pageSpacing
        
        // Set canvas view full width
        canvasView.frame = CGRect(
            x: 0,
            y: 0,
            width: scrollView.frame.width > 0 ? scrollView.frame.width : UIScreen.main.bounds.width,
            height: totalHeight
        )
        
        // Set up the tool picker
        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        
        // Add the canvas view to the scroll view
        scrollView.addSubview(canvasView)
        scrollView.contentSize = canvasView.frame.size
        
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
            let yPosition = pageHeight * CGFloat(i) + pageSpacing * CGFloat(i - 1)
            
            let dividerView = UIView()
            dividerView.frame = CGRect(
                x: 0,
                y: yPosition,
                width: canvasWidth,
                height: pageSpacing
            )
            dividerView.backgroundColor = .clear
            dividerView.tag = 999
            
            // Add dashed line
            let dashedLine = CAShapeLayer()
            dashedLine.strokeColor = UIColor.systemGray4.cgColor
            dashedLine.lineDashPattern = [4, 4]
            dashedLine.lineWidth = 1
            
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: pageSpacing / 2))
            path.addLine(to: CGPoint(x: canvasWidth, y: pageSpacing / 2))
            dashedLine.path = path.cgPath
            
            dividerView.layer.addSublayer(dashedLine)
            
            // Page label
            let label = UILabel()
            label.text = "Page \(i + 1)"
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .systemGray
            label.sizeToFit()
            label.center = CGPoint(x: canvasWidth / 2, y: pageSpacing / 2)
            dividerView.addSubview(label)
            
            scrollView.addSubview(dividerView)
        }
    }
}

// MARK: - TemplateRenderer Extension to make it public for other views
extension TemplateRenderer {
    // This is needed to ensure that the TemplateRenderer can be accessed from the notification handler
    // Make sure this matches your existing TemplateRenderer implementation
    static func applyTemplateImmediately(to canvasView: PKCanvasView, template: CanvasTemplate, pageSize: CGSize, numberOfPages: Int, pageSpacing: CGFloat) {
        applyTemplateToCanvas(canvasView, template: template, pageSize: pageSize, numberOfPages: numberOfPages, pageSpacing: pageSpacing)
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
