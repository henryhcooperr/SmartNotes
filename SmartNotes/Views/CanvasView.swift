//
//  CanvasView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI
import PencilKit

/// A wrapper for PKCanvasView so we can use PencilKit in SwiftUI.
struct CanvasView: UIViewRepresentable {
    
    // Binding to store the PKDrawing from the canvas
    @Binding var drawing: PKDrawing

    // The tool picker can be shown or hidden.
    let toolPicker = PKToolPicker()

    // Create the initial PKCanvasView.
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .white
        canvasView.drawingPolicy = .anyInput  // allows finger & Pencil
        canvasView.drawing = drawing

        // Setup default tool
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)

        // Enable pencil interactions
        canvasView.allowsFingerDrawing = true

        // Show the tool picker - using the more modern API
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    // Keep the UIView in sync with SwiftUI updates.
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
    }
}
