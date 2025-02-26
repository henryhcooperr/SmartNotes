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
    @State private var numberOfPages: Int = 2 // Start with 2 pages
    
    // Constants
    private let pageSize = CGSize(width: 612, height: 792) // US Letter
    private let pageSpacing: CGFloat = 20
    
    // Add storage of template with note
    private let templateKey = "note.template"
    
    var body: some View {
        ZStack {
            // Background template (rendered using SwiftUI)
            SimpleTemplateView(
                template: template,
                pageSize: pageSize,
                numberOfPages: numberOfPages,
                pageSpacing: pageSpacing
            )
            
            // Canvas for drawing (sitting on top)
            CanvasWithExpandingPages(
                drawing: $drawing,
                numberOfPages: $numberOfPages,
                pageSize: pageSize,
                pageSpacing: pageSpacing
            )
        }
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

// This is a simplified canvas view that focuses only on drawing and page management
struct CanvasWithExpandingPages: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var numberOfPages: Int
    let pageSize: CGSize
    let pageSpacing: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasWithExpandingPages
        var canvasView: PKCanvasView?
        var lastUpdate = Date()
        var isInitialLoad = true
        
        init(_ parent: CanvasWithExpandingPages) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Skip updates during initial load
            if isInitialLoad {
                return
            }
            
            // Debounce updates
            let now = Date()
            if now.timeIntervalSince(lastUpdate) < 0.3 {
                return // Skip rapid updates
            }
            
            lastUpdate = now
            
            // Update the drawing binding
            parent.drawing = canvasView.drawing
            
            // Check if we need to add a new page
            checkAndAddNewPageIfNeeded(canvasView: canvasView)
        }
        
        func checkAndAddNewPageIfNeeded(canvasView: PKCanvasView) {
            // Check if any stroke extends near the bottom of the last page
            let strokes = canvasView.drawing.strokes
            
            // Calculate the bottom of the last page
            let lastPageBottom = CGFloat(parent.numberOfPages) * (parent.pageSize.height + parent.pageSpacing) - parent.pageSpacing
            
            // Check if any stroke extends below 80% of the last page
            let thresholdY = lastPageBottom - (parent.pageSize.height * 0.2)
            
            for stroke in strokes {
                if stroke.renderBounds.maxY > thresholdY {
                    // Add a new page
                    DispatchQueue.main.async {
                        self.parent.numberOfPages += 1
                        print("📝 Added new page, total: \(self.parent.numberOfPages)")
                    }
                    break
                }
            }
        }
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // Create the scroll view
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = .clear // Important: transparent background
        
        // Create the canvas
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear // Important: transparent background
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = context.coordinator
        context.coordinator.canvasView = canvasView
        
        // Set up the canvas size
        updateCanvasFrame(canvasView, in: scrollView)
        
        // Add the canvas to the scroll view
        scrollView.addSubview(canvasView)
        
        // Set up the tool picker
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        // Load the drawing with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            canvasView.drawing = drawing
            
            // Mark initialization as complete after another delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                context.coordinator.isInitialLoad = false
            }
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let canvasView = context.coordinator.canvasView else { return }
        
        // Update drawing if needed
        if canvasView.drawing != drawing && !context.coordinator.isInitialLoad {
            canvasView.drawing = drawing
        }
        
        // Update canvas size and scroll view content size
        updateCanvasFrame(canvasView, in: scrollView)
    }
    
    private func updateCanvasFrame(_ canvasView: PKCanvasView, in scrollView: UIScrollView) {
        // Calculate total height
        let totalHeight = CGFloat(numberOfPages) * (pageSize.height + pageSpacing) - pageSpacing
        
        // Update canvas frame
        let canvasWidth = min(scrollView.frame.width - 40, pageSize.width)
        canvasView.frame = CGRect(
            x: (scrollView.frame.width - canvasWidth) / 2,
            y: 0,
            width: canvasWidth,
            height: totalHeight
        )
        
        // Update scroll view content size
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: totalHeight)
    }
}
