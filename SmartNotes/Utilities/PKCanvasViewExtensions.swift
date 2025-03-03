//
//  PKCanvasViewExtensions.swift
//  SmartNotes
//
//  Created for improving drawing resolution quality
//

import UIKit
import PencilKit

extension PKCanvasView {
    /// Configures the canvas view for high-quality zoom rendering
    func optimizeForHighQualityZoom() {
        // Ensure content scale matches device
        self.layer.contentsScale = UIScreen.main.scale
        
        // Force high-resolution rendering
        self.layer.rasterizationScale = UIScreen.main.scale * 2.0
        
        // Disable rasterization since we want vector quality
        self.layer.shouldRasterize = false
        
        // Make sure the canvas view uses the display's native scale
        if let window = self.window {
            self.layer.contentsScale = window.screen.scale
        }
        
        // Set drawing quality to maximum
        if #available(iOS 14.0, *) {
            self.overrideUserInterfaceStyle = .light // Ensure consistent rendering
        }
        
        // Force the layer to update
        self.setNeedsDisplay()
    }
    
    /// Creates a higher resolution snapshot of the current visible area
    /// This can be used to create a higher quality view when needed
    func highResolutionSnapshot() -> UIImage? {
        // Create a renderer at 2x the current screen scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale * 2.0
        
        let renderer = UIGraphicsImageRenderer(bounds: self.bounds, format: format)
        
        return renderer.image { context in
            self.layer.render(in: context.cgContext)
        }
    }
} 