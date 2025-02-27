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
    
    // Add storage of template with note
    private let templateKey = "note.template"
    
    var body: some View {
        SafeCanvasView(drawing: $drawing, template: $template)
            .sheet(isPresented: $showingTemplateSettings) {
                TemplateSettingsView(template: $template)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTemplateSettings"))) { _ in
                showingTemplateSettings = true
            }
            .onAppear {
                // Try to load saved template settings from UserDefaults
                if let savedData = UserDefaults.standard.data(forKey: templateKey) {
                    do {
                        let savedTemplate = try JSONDecoder().decode(CanvasTemplate.self, from: savedData)
                        template = savedTemplate
                        print("📝 Loaded template settings: \(savedTemplate.type.rawValue)")
                    } catch {
                        print("📝 Error loading template settings: \(error)")
                    }
                }
            }
            .onChange(of: template) { newTemplate in
                // Save template settings when they change
                do {
                    let data = try JSONEncoder().encode(newTemplate)
                    UserDefaults.standard.set(data, forKey: templateKey)
                    print("📝 Template changed to: \(newTemplate.type.rawValue), spacing: \(newTemplate.spacing)")
                } catch {
                    print("📝 Error saving template settings: \(error)")
                }
            }
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
            guard let canvasView = canvasView, !canvasView.frame.isEmpty else { return }
            
            // Only apply if template changed
            guard parent.template != lastTemplate else { return }
            
            if parent.template.type == .none {
                // Simply set white background
                canvasView.backgroundColor = .white
            } else {
                // Apply template via TemplateRenderer
                TemplateRenderer.applyTemplateToCanvas(
                    canvasView,
                    template: parent.template,
                    pageSize: CGSize(width: parent.pageWidth, height: parent.pageHeight),
                    numberOfPages: parent.initialPages,
                    pageSpacing: parent.pageSpacing
                )
            }
            
            lastTemplate = parent.template
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
        
        // Set up the tool picker
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        // We'll safely size and add the canvas view in updateUIView to ensure
        // we have valid frame dimensions first
        
        // Load drawing after a slight delay to allow view setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            canvasView.drawing = drawing
            
            // Mark initialization complete after drawing is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                context.coordinator.isInitialLoad = false
            }
        }
        
        // Add the canvas view to the scroll view
        scrollView.addSubview(canvasView)
        
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
// MARK: - Previews
#Preview {
    NavigationView {
        TemplateCanvasView(drawing: .constant(PKDrawing()), showExportMenu: .constant(false))
            .navigationTitle("Template Preview")
    }
}

// Preview helper extension for TemplateCanvasView
extension TemplateCanvasView {
    /// Preview initializer that uses constant bindings for simpler testing
    init(drawing: Binding<PKDrawing>, showExportMenu: Binding<Bool>) {
        self._drawing = drawing
        self._showingTemplateSettings = State(initialValue: false)
        self._template = State(initialValue: .graph) // Default to graph paper for preview
    }
}
