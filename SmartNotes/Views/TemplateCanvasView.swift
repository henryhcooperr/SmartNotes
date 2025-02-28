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
        
        // Check if drawing extends to the last page
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
            
            // Trigger threshold near bottom of the last page
            let triggerThreshold = lastPageBottom - (pageHeight * 0.3)
            
            // If the drawing extends beyond the trigger threshold, add a page
            if drawingBounds.maxY > triggerThreshold {
                print("📐 Drawing extends near last page bottom, adding a new page")
                
                DispatchQueue.main.async {
                    self.parent.numberOfPages += 1
                    print("📐 New page count: \(self.parent.numberOfPages)")
                    
                    // Update the scroll view and canvas
                    self.updateContentSizeAndDividers()
                    
                    // Scroll to show part of the new page
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let scrollView = self.mainScrollView {
                            let newPageTop = lastPageBottom + self.parent.pageSpacing
                            let newContentOffset = CGPoint(
                                x: 0,
                                y: newPageTop - (scrollView.frame.height * 0.7)
                            )
                            scrollView.setContentOffset(newContentOffset, animated: true)
                        }
                    }
                }
            }
        }
        
        // Update scroll view content size and redraw page dividers
        func updateContentSizeAndDividers() {
            guard let scrollView = self.mainScrollView,
                  let canvasView = self.canvasView else {
                print("📐 Error: Missing scrollView or canvasView")
                return
            }
            
            // Total content height
            let totalHeight = CGFloat(parent.numberOfPages)
                            * (parent.pageHeight + parent.pageSpacing)
                            - parent.pageSpacing
            
            print("📐 Updating content size to height: \(totalHeight)")
            
            let availableWidth = scrollView.frame.width
            let maxCanvasWidth = min(availableWidth, parent.pageWidth)
            
            // Update the canvas frame
            let newCanvasFrame = CGRect(
                x: (availableWidth - maxCanvasWidth) / 2, // center horizontally
                y: 0,
                width: maxCanvasWidth,
                height: totalHeight
            )
            
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
        
        func updatePageDividers() {
            guard let canvasView = self.canvasView else { return }
            
            // Remove existing dividers
            for dividerView in dividerViews {
                dividerView.removeFromSuperview()
            }
            dividerViews.removeAll()
            
            // Don't do anything if it's still initial loading
            if isInitialLoad { return }
            
            // The width of the (unscaled) canvas
            let canvasWidth = canvasView.frame.width
            
            // For each boundary between pages, place a dashed line
            for i in 1..<parent.numberOfPages {
                let yPosition = parent.pageHeight * CGFloat(i)
                               + parent.pageSpacing * CGFloat(i - 1)
                
                let dividerView = UIView()
                dividerView.frame = CGRect(
                    x: 0,
                    y: yPosition,
                    width: canvasWidth,
                    height: parent.pageSpacing
                )
                dividerView.backgroundColor = .clear
                
                let lineLayer = CAShapeLayer()
                lineLayer.strokeColor = UIColor.systemGray4.cgColor
                lineLayer.lineDashPattern = [4, 4]
                lineLayer.lineWidth = 1
                
                // Draw the line horizontally across the dividerView's width
                let path = UIBezierPath()
                path.move(to: CGPoint(
                    x: 0,
                    y: dividerView.frame.height / 2
                ))
                path.addLine(to: CGPoint(
                    x: dividerView.frame.width,
                    y: dividerView.frame.height / 2
                ))
                lineLayer.path = path.cgPath
                
                dividerView.layer.addSublayer(lineLayer)
                
                // Optional label
                let pageLabel = UILabel()
                pageLabel.text = "Page \(i + 1)"
                pageLabel.textColor = .systemGray
                pageLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
                pageLabel.sizeToFit()
                pageLabel.center = CGPoint(
                    x: dividerView.frame.width / 2,
                    y: dividerView.frame.height / 2
                )
                dividerView.addSubview(pageLabel)
                
                canvasView.addSubview(dividerView)
                dividerViews.append(dividerView)
            }
        }
        
        func applyTemplate() {
            guard let canvasView = canvasView else { return }
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
            
            // Make canvas first responder
            if !canvasView.isFirstResponder {
                print("🔧 Canvas is not first responder - making it first responder")
                canvasView.becomeFirstResponder()
            }
        }
        
        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return canvasView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Center the zooming canvas if smaller than the scroll view
            centerZoomingView(in: scrollView)
            
            // ⚠️ We do NOT call updatePageDividers() here,
            // because that would re-layout subviews using unscaled coords.
            // The scroll view will scale them automatically.
        }
        
        private func centerZoomingView(in scrollView: UIScrollView) {
            guard let canvasView = canvasView else { return }
            
            let offsetX = max(
                (scrollView.bounds.width - canvasView.frame.width * scrollView.zoomScale) * 0.5,
                0
            )
            let offsetY = max(
                (scrollView.bounds.height - canvasView.frame.height * scrollView.zoomScale) * 0.5,
                0
            )
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
        let scrollView = UIScrollView()
        scrollView.decelerationRate = .fast
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .systemBackground
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.bouncesZoom = true
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.contentInsetAdjustmentBehavior = .automatic
        context.coordinator.mainScrollView = scrollView
        
        // Create the PKCanvasView
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .white
        canvasView.alwaysBounceVertical = true
        
        // Respect user preference for disabling finger drawing
        let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
        if #available(iOS 16.0, *) {
            canvasView.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
        } else {
            canvasView.allowsFingerDrawing = !disableFingerDrawing
        }
        
        context.coordinator.canvasView = canvasView
        
        // Calculate initial content height & width
        let totalHeight = CGFloat(numberOfPages) * (pageHeight + pageSpacing) - pageSpacing
        let availableWidth = scrollView.frame.width > 0
            ? scrollView.frame.width
            : UIScreen.main.bounds.width
        let canvasWidth = min(availableWidth, pageWidth)
        
        // Set up the canvas frame
        canvasView.frame = CGRect(
            x: (availableWidth - canvasWidth) / 2, // center horizontally
            y: 0,
            width: canvasWidth,
            height: totalHeight
        )
        
        // Set up the PKToolPicker
        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        
        // Add canvas to the scroll view
        scrollView.addSubview(canvasView)
        scrollView.contentSize = CGSize(width: availableWidth, height: totalHeight)
        
        // Load the existing drawing asynchronously
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            canvasView.drawing = drawing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                toolPicker.setVisible(true, forFirstResponder: canvasView)
                canvasView.becomeFirstResponder()
                
                // Update layout & page dividers
                context.coordinator.updateContentSizeAndDividers()
                context.coordinator.isInitialLoad = false
                print("📝 Canvas ready with tool picker visible")
            }
        }
        
        // Observe a notification to force the tool picker
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CanvasForceFirstResponder"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔧 Forcing tool picker visibility from notification")
            context.coordinator.ensureToolPickerVisible()
            context.coordinator.updateContentSizeAndDividers()
        }

        // Observe the RefreshTemplate notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshTemplate"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 RefreshTemplate notification received - reapplying template")
            context.coordinator.applyTemplate()
            context.coordinator.updateContentSizeAndDividers()
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let canvasView = context.coordinator.canvasView else { return }
        
        // Only proceed if the scroll view has valid dimensions
        guard scrollView.frame.width > 0, scrollView.frame.height > 0 else {
            print("⚠️ SafeCanvasView: Invalid scrollView dimensions: \(scrollView.frame.size)")
            return
        }
        
        // 1) If the canvas has finished loading and our PKDrawing changed, update it
        if !context.coordinator.isInitialLoad, canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }
        
        // 2) Re-apply the user's template settings if they've changed
        if !context.coordinator.isInitialLoad,
           context.coordinator.lastTemplate != template {
            print("✏️ Template has changed, applying new settings...")
            context.coordinator.applyTemplate()
        }

        // 3) Respect the 'Disable Finger Drawing' setting each time
        let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
        if #available(iOS 16.0, *) {
            canvasView.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
        } else {
            canvasView.allowsFingerDrawing = !disableFingerDrawing
        }
        
        // 4) Periodically ensure the canvas is first responder so the tool picker remains visible
        if !context.coordinator.isInitialLoad && !canvasView.isFirstResponder {
            context.coordinator.ensureToolPickerVisible()
        }
        
        // 5) Optionally refresh page dividers if the view size changed
        //    (e.g. device rotation). But do NOT multiply by zoomScale.
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
