//
//  CanvasManager.swift
//  SmartNotes
//
//  Created on 5/15/25
//
//  This file centralizes all canvas-related operations throughout the app.
//  Key responsibilities:
//    - Creating and configuring PKCanvasView instances with proper settings
//    - Managing drawing tools and their application to canvases
//    - Optimizing canvas performance based on interaction state
//    - Applying templates consistently across canvases
//    - Providing utilities for drawing state operations (undo/redo)
//

import Foundation
import UIKit
import PencilKit
import SwiftUI
import ObjectiveC

/// Central manager for all canvas-related operations
class CanvasManager {
    // MARK: - Singleton Access
    
    /// Shared instance for app-wide access
    static let shared = CanvasManager()
    
    // Subscription manager for event handling
    private var subscriptionManager = SubscriptionManager()
    
    // Private initialization prevents multiple instances
    private init() {
        // Initialize with default tool settings
        currentTool = .pen
        currentColor = UIColor.black
        currentLineWidth = 2.0 * ResolutionManager.shared.resolutionScaleFactor
        
        // Load user preferences if available
        loadToolPreferences()
        
        print("🖋️ CanvasManager: Initialized with tool \(currentTool)")
    }
    
    deinit {
        // Clean up all subscriptions
        subscriptionManager.clearAll()
    }
    
    // MARK: - Canvas Tracking
    
    /// Track all active canvases for batch operations
    private var activeCanvases: [UUID: WeakCanvasReference] = [:]
    
    /// Wrapper for weak references to canvases
    private class WeakCanvasReference {
        weak var canvas: PKCanvasView?
        
        init(_ canvas: PKCanvasView) {
            self.canvas = canvas
        }
    }
    
    // Use associated objects to store canvas IDs instead of fileprivate tagID
    private var canvasIDKey = "CanvasManagerIDKey"
    
    /// Set ID for a canvas using associated objects
    private func setCanvasID(_ canvas: PKCanvasView, id: UUID) {
        objc_setAssociatedObject(canvas, &canvasIDKey, id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    /// Get ID from a canvas
    private func getCanvasID(_ canvas: PKCanvasView) -> UUID? {
        return objc_getAssociatedObject(canvas, &canvasIDKey) as? UUID
    }
    
    /// Register a canvas to be managed
    func registerCanvas(_ canvas: PKCanvasView, withID id: UUID) {
        // Store the ID with the canvas using associated objects
        setCanvasID(canvas, id: id)
        
        // Store a weak reference to the canvas
        activeCanvases[id] = WeakCanvasReference(canvas)
        
        // Clean up any nil references
        cleanupCanvasReferences()
        
        // Immediately apply the current tool to the newly registered canvas
        applyCurrentTool(to: canvas)
        
        print("🖋️ CanvasManager: Registered canvas with ID \(id.uuidString.prefix(8))")
    }
    
    /// Unregister a canvas when it's no longer needed
    func unregisterCanvas(withID id: UUID) {
        activeCanvases.removeValue(forKey: id)
        print("🖋️ CanvasManager: Unregistered canvas with ID \(id.uuidString.prefix(8))")
    }
    
    /// Clean up any nil references from the canvases dictionary
    private func cleanupCanvasReferences() {
        for (id, reference) in activeCanvases {
            if reference.canvas == nil {
                activeCanvases.removeValue(forKey: id)
            }
        }
    }
    
    /// Get a canvas by ID
    func getCanvas(withID id: UUID) -> PKCanvasView? {
        return activeCanvases[id]?.canvas
    }
    
    // MARK: - Canvas Creation & Configuration
    
    /// Current tool properties
    private(set) var currentTool: PKInkingTool.InkType
    private(set) var currentColor: UIColor
    private(set) var currentLineWidth: CGFloat
    
    /// Create a new PKCanvasView with proper configuration
    func createCanvas(withID id: UUID? = nil, initialDrawing: Data? = nil) -> PKCanvasView {
        let canvas = PKCanvasView()
        
        // Set the ID if provided using associated objects
        if let id = id {
            setCanvasID(canvas, id: id)
            registerCanvas(canvas, withID: id)
        }
        
        // Load initial drawing if provided
        if let drawingData = initialDrawing {
            canvas.drawing = PKDrawing.fromData(drawingData)
        }
        
        // Configure the canvas
        configureCanvas(canvas)
        
        return canvas
    }
    
    /// Configure a canvas with standard settings
    func configureCanvas(_ canvas: PKCanvasView) {
        // Initialize standard properties
        canvas.backgroundColor = .white
        canvas.alwaysBounceVertical = false
        canvas.contentInset = .zero
        
        // Apply finger drawing policy based on settings
        let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
        if #available(iOS 16.0, *) {
            canvas.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
        } else {
            canvas.allowsFingerDrawing = !disableFingerDrawing
        }
        
        // Optimize for high resolution drawing
        optimizeCanvasForHighResolution(canvas)
        
        // Register for resolution changes
        canvas.registerForResolutionChanges()
        
        // Apply the current tool
        applyCurrentTool(to: canvas)
    }
    
    // MARK: - Performance Optimization
    
    /// Optimize a canvas for high resolution rendering
    func optimizeCanvasForHighResolution(_ canvas: PKCanvasView) {
        // Get the resolution scale factor directly
        let scaleFactor = ResolutionManager.shared.resolutionScaleFactor
        
        // Apply to canvas content scale
        canvas.contentScaleFactor = UIScreen.main.scale * scaleFactor
        
        // Apply to layer as well for consistent scaling
        canvas.layer.contentsScale = UIScreen.main.scale * scaleFactor
        canvas.layer.rasterizationScale = UIScreen.main.scale * scaleFactor
        canvas.layer.shouldRasterize = false
        
        // Make sure the canvas view uses the display's native scale
        if let window = canvas.window {
            canvas.layer.contentsScale = window.screen.scale * scaleFactor
        }
        
        // For iOS 14+ we can use higher quality rendering policy
        if #available(iOS 14.0, *) {
            let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
            canvas.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
            canvas.overrideUserInterfaceStyle = .light // Ensure consistent rendering
        }
        
        // Ensure child layers also use high resolution rendering
        optimizeLayerHierarchy(canvas.layer, scaleFactor: scaleFactor)
        
        // Force the layer to update
        canvas.setNeedsDisplay()
    }
    
    /// Recursively sets the contentsScale on a layer and its sublayers
    private func optimizeLayerHierarchy(_ layer: CALayer, scaleFactor: CGFloat) {
        // Set high resolution scale on this layer
        layer.contentsScale = UIScreen.main.scale * scaleFactor
        
        // Apply to all sublayers recursively
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                optimizeLayerHierarchy(sublayer, scaleFactor: scaleFactor)
            }
        }
    }
    
    /// Adjust canvas quality based on zoom level
    func adjustQualityForZoom(_ canvas: PKCanvasView, zoomScale: CGFloat) {
        // Get resolution scale factor
        let resolutionFactor = ResolutionManager.shared.resolutionScaleFactor
        
        // Calculate the effective zoom considering our resolution scale factor
        let effectiveZoom = zoomScale * resolutionFactor
        
        // For very high zoom levels, ensure maximum quality
        if effectiveZoom > 2.0 {
            if #available(iOS 14.0, *) {
                canvas.drawingPolicy = .pencilOnly
            }
        } else {
            // For lower zoom levels, use standard quality which performs better
            let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
            if #available(iOS 14.0, *) {
                canvas.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
            }
        }
        
        // Force redraw with the new quality settings
        canvas.setNeedsDisplay()
    }
    
    /// Set temporary low resolution mode during interactions
    func setTemporaryLowResolutionMode(_ canvas: PKCanvasView, enabled: Bool) {
        // Get resolution scale factor
        let resolutionFactor = ResolutionManager.shared.resolutionScaleFactor
        
        if enabled {
            // Use lower scale factor during interactions for better performance
            let temporaryFactor = min(2.0, resolutionFactor)
            canvas.layer.contentsScale = UIScreen.main.scale * temporaryFactor
            
            // Lower rendering quality during interaction for better performance
            if #available(iOS 14.0, *) {
                canvas.drawingPolicy = .anyInput
            }
        } else {
            // Restore full resolution after interaction ends
            canvas.layer.contentsScale = UIScreen.main.scale * resolutionFactor
            
            // Restore quality based on current zoom if in a scroll view
            if let scrollView = canvas.superview as? UIScrollView {
                adjustQualityForZoom(canvas, zoomScale: scrollView.zoomScale)
            } else {
                // Default back to high quality if not in a scroll view
                let disableFingerDrawing = UserDefaults.standard.bool(forKey: "disableFingerDrawing")
                if #available(iOS 14.0, *) {
                    canvas.drawingPolicy = disableFingerDrawing ? .pencilOnly : .anyInput
                }
            }
        }
        
        // Force redraw with new quality settings
        canvas.setNeedsDisplay()
    }
    
    /// Creates a higher resolution snapshot of the canvas
    func highResolutionSnapshot(of canvas: PKCanvasView) -> UIImage? {
        // Get resolution scale factor
        let resolutionFactor = ResolutionManager.shared.resolutionScaleFactor
        
        // Create a renderer at our scaled resolution
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale * resolutionFactor
        
        let renderer = UIGraphicsImageRenderer(bounds: canvas.bounds, format: format)
        
        return renderer.image { context in
            canvas.layer.render(in: context.cgContext)
        }
    }
    
    // MARK: - Tool Management
    
    /// Set the current drawing tool
    func setTool(_ tool: PKInkingTool.InkType, color: UIColor, width: CGFloat) {
        // Update current tool properties
        currentTool = tool
        currentColor = color
        currentLineWidth = width
        
        // Save preferences
        saveToolPreferences()
        
        // Apply to all active canvases
        applyToolToAllCanvases()
        
        // Notify that tool has changed using EventBus
        notifyToolChanged()
    }
    
    /// Clear tool selection - sets canvases to have no active tool
    func clearToolSelection() {
        // Clean up references first
        cleanupCanvasReferences()
        
        // Disable drawing on all canvases
        for (_, reference) in activeCanvases {
            if let canvas = reference.canvas {
                // Instead of using a transparent pen, disable interactions entirely
                canvas.isUserInteractionEnabled = false
            }
        }
        
        // Notify that tool has been cleared
        print("🖋️ CanvasManager: Cleared tool selection from all canvases")
    }
    
    /// Re-enable interaction on all canvases
    func enableCanvasInteractions() {
        // Clean up references first
        cleanupCanvasReferences()
        
        // Enable drawing on all canvases
        for (_, reference) in activeCanvases {
            if let canvas = reference.canvas {
                canvas.isUserInteractionEnabled = true
            }
        }
        
        print("🖋️ CanvasManager: Re-enabled interaction on all canvases")
    }
    
    /// Apply the current tool to a specific canvas
    func applyCurrentTool(to canvas: PKCanvasView) {
        // First make sure interaction is enabled
        canvas.isUserInteractionEnabled = true
        
        // Handle eraser separately since it's not part of PKInkingTool.InkType
        if currentTool == .pen && currentColor.isEqual(UIColor.clear) {
            // Use PencilKit's eraser when tool is pen but color is clear
            canvas.tool = PKEraserTool(.bitmap)
        } else {
            // Use inking tool with current properties
            let inkingTool = PKInkingTool(currentTool, color: currentColor, width: currentLineWidth)
            canvas.tool = inkingTool
        }
    }
    
    /// Apply the current tool to all active canvases
    func applyToolToAllCanvases() {
        // Clean up references first
        cleanupCanvasReferences()
        
        // Then apply tool to all canvases
        for (_, reference) in activeCanvases {
            if let canvas = reference.canvas {
                applyCurrentTool(to: canvas)
            }
        }
    }
    
    /// Save current tool preferences
    private func saveToolPreferences() {
        // Convert color to hex for storage
        let colorHex = currentColor.hexString
        
        // Save to UserDefaults
        UserDefaults.standard.set(currentTool.rawValue, forKey: "lastToolType")
        UserDefaults.standard.set(colorHex, forKey: "lastToolColor")
        UserDefaults.standard.set(currentLineWidth, forKey: "lastToolWidth")
    }
    
    /// Load tool preferences from UserDefaults
    private func loadToolPreferences() {
        // Load tool type if available
        if let toolRawValue = UserDefaults.standard.string(forKey: "lastToolType"),
           let tool = PKInkingTool.InkType(rawValue: toolRawValue) {
            currentTool = tool
        }
        
        // Load color if available
        if let colorHex = UserDefaults.standard.string(forKey: "lastToolColor"),
           let color = UIColor(hexString: colorHex) {
            currentColor = color
        }
        
        // Load line width if available
        if let width = UserDefaults.standard.object(forKey: "lastToolWidth") as? CGFloat {
            currentLineWidth = width
        }
    }
    
    /// Notify that tool has changed
    private func notifyToolChanged() {
        // Use EventBus with the proper publish method
        let event = ToolEvents.ToolChanged(tool: currentTool, color: currentColor, width: currentLineWidth)
        EventBus.shared.publish(event)
    }
    
    // MARK: - Template Application
    
    /// Apply a template to a canvas
    func applyTemplate(to canvas: PKCanvasView, template: CanvasTemplate, pageSize: CGSize) {
        // Use TemplateRenderer to apply the template
        TemplateRenderer.applyTemplateToCanvas(
            canvas,
            template: template,
            pageSize: pageSize,
            numberOfPages: 1,
            pageSpacing: 0
        )
    }
    
    /// Apply a template to all active canvases
    func applyTemplateToAllCanvases(_ template: CanvasTemplate, pageSize: CGSize) {
        // Clean up references first
        cleanupCanvasReferences()
        
        // Then apply template to all canvases
        for (_, reference) in activeCanvases {
            if let canvas = reference.canvas {
                applyTemplate(to: canvas, template: template, pageSize: pageSize)
            }
        }
    }
    
    // MARK: - Drawing State Operations
    
    /// Undo the last operation on a canvas
    func undo(_ canvas: PKCanvasView) {
        if canvas.undoManager?.canUndo ?? false {
            canvas.undoManager?.undo()
        }
    }
    
    /// Redo the last undone operation on a canvas
    func redo(_ canvas: PKCanvasView) {
        if canvas.undoManager?.canRedo ?? false {
            canvas.undoManager?.redo()
        }
    }
    
    /// Clear all drawing content from a canvas
    func clearCanvas(_ canvas: PKCanvasView) {
        canvas.drawing = PKDrawing()
    }
}

// MARK: - Helper Extensions

extension UIColor {
    /// Convert a UIColor to a hex string
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(
            format: "#%02X%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255),
            Int(a * 255)
        )
    }
    
    /// Create a UIColor from a hex string
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

// MARK: - PKCanvasView Extensions

extension PKCanvasView {
    /// Get drawing data representation
    func getDrawingData() -> Data? {
        return try? drawing.dataRepresentation()
    }
    
    /// Set drawing from data
    static func fromData(_ data: Data) -> PKDrawing {
        if data.isEmpty {
            return PKDrawing()
        }
        
        do {
            return try PKDrawing(data: data)
        } catch {
            print("Error creating PKDrawing from data: \(error)")
            return PKDrawing()
        }
    }
} 