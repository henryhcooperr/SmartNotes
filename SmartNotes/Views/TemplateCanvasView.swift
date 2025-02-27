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
    
    // Properly associate template with the specific note
    var noteID: UUID
    private var templateKey: String {
        "note.template.\(noteID.uuidString)"  // Make key unique per note
    }
    
    var body: some View {
        SafeCanvasView(drawing: $drawing, template: $template)
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

/// A complete rewrite of the canvas view with strict geometry validation - implemented in the same file
struct SafeCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var template: CanvasTemplate
    
    // Standard dimensions
    private let pageWidth: CGFloat = 612 // 8.5" at 72 DPI
    private let pageHeight: CGFloat = 792 // 11" at 72 DPI
    private let pageSpacing: CGFloat = 20
    private let initialPages: Int = 2
    
    class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        var parent: SafeCanvasView
        var canvasView: PKCanvasView?
        var scrollView: UIScrollView?
        var isInitialLoad = true
        var lastTemplate: CanvasTemplate?
        var toolPicker: PKToolPicker?
        
        init(_ parent: SafeCanvasView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Only update after initial load
            if !isInitialLoad {
                DispatchQueue.main.async {
                    self.parent.drawing = canvasView.drawing
                }
            }
        }
        
        func applyTemplate() {
            guard let canvasView = canvasView else { return }
            
            // Ensure canvas has valid dimensions before applying template
            guard !canvasView.frame.isEmpty,
                  canvasView.frame.width > 10,
                  canvasView.frame.height > 10 else {
                print("🖌️ Canvas dimensions invalid: \(canvasView.frame.size), retrying...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.applyTemplate()
                }
                return
            }
            
            // Always apply template regardless of lastTemplate state
            print("🖌️ Forcing template application: \(parent.template.type.rawValue)")
            
            TemplateRenderer.applyTemplateToCanvas(
                canvasView,
                template: parent.template,
                pageSize: CGSize(width: parent.pageWidth, height: parent.pageHeight),
                numberOfPages: parent.initialPages,
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // Create the scroll view container
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .systemBackground
        context.coordinator.scrollView = scrollView
        
        // Create the canvas with fixed, safe dimensions
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        context.coordinator.canvasView = canvasView
        
        // Store canvas view reference for use in notifications
        let canvasViewRef = canvasView
        
        // Set up the tool picker - IMPROVED IMPLEMENTATION
        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        
        // Add the canvas view to the scroll view
        scrollView.addSubview(canvasView)
        
        // Load drawing after a slight delay to allow view setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            canvasView.drawing = drawing
            
            // Make canvas first responder AFTER drawing is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Force the tool picker to show
                toolPicker.setVisible(true, forFirstResponder: canvasView)
                toolPicker.addObserver(canvasView)
                canvasView.becomeFirstResponder()
                
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
        
        // Calculate safe dimensions
        let safeWidth = min(scrollView.frame.width, pageWidth)
        let totalHeight = CGFloat(initialPages) * pageHeight + CGFloat(initialPages - 1) * pageSpacing
        let safeHeight = max(totalHeight, scrollView.frame.height * 2)
        
        // Set canvas size safely
        let canvasFrame = CGRect(
            x: (scrollView.frame.width - safeWidth) / 2,
            y: 0,
            width: safeWidth,
            height: safeHeight
        )
        
        // Only set frame if dimensions are valid
        if canvasFrame.size.width > 0, canvasFrame.size.height > 0,
           !canvasFrame.size.width.isNaN, !canvasFrame.size.height.isNaN {
            canvasView.frame = canvasFrame
        }
        
        // Set content size
        let contentSize = CGSize(width: scrollView.frame.width, height: safeHeight)
        if contentSize.width > 0, contentSize.height > 0,
           !contentSize.width.isNaN, !contentSize.height.isNaN {
            scrollView.contentSize = contentSize
        }
        
        // Update drawing
        if !context.coordinator.isInitialLoad, canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }
        
        // Apply template if needed
        context.coordinator.applyTemplate()
        
        // Draw page dividers
        drawPageDividers(in: scrollView, canvasWidth: safeWidth)
        
        // This is crucial - make sure canvasView is first responder on EVERY update
        // This fixes cases where tools disappear after app switching or other interruptions
        if !context.coordinator.isInitialLoad && !canvasView.isFirstResponder {
            // Every 5th update, ensure visibility
            if context.coordinator.toolPicker != nil && arc4random_uniform(5) == 0 {
                context.coordinator.ensureToolPickerVisible()
            }
        }
    }
    
    // Draw visual indicators for page breaks
    private func drawPageDividers(in scrollView: UIScrollView, canvasWidth: CGFloat) {
        // Remove existing dividers
        for view in scrollView.subviews where view.tag == 999 {
            view.removeFromSuperview()
        }
        
        // Add dividers for each page
        for i in 1..<initialPages {
            let yPosition = pageHeight * CGFloat(i) + pageSpacing * CGFloat(i - 1)
            
            let dividerView = UIView()
            dividerView.frame = CGRect(
                x: (scrollView.frame.width - canvasWidth) / 2,
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
