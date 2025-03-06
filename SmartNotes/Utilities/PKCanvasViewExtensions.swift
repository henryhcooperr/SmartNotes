//
//  PKCanvasViewExtensions.swift
//  SmartNotes
//
//  Created for improving drawing resolution quality
//
//  This file contains extensions for PencilKit's PKCanvasView to improve
//  drawing quality and rendering performance, especially when zooming.
//

import UIKit
import PencilKit

// MARK: - PKCanvasView Extensions for High Resolution Rendering
extension PKCanvasView: ResolutionChangeObserver {
    
    /// Called when resolution changes to update canvas rendering
    func resolutionDidChange(newResolutionFactor: CGFloat) {
        // Update content scale factor based on the new resolution
        optimizeForHighResolution()
        
        // Force redraw with the new resolution
        self.setNeedsDisplay()
    }
    
    /// Registers this canvas view to receive resolution change notifications
    func registerForResolutionChanges() {
        // Add this canvas as an observer
        ResolutionManager.shared.addObserver(self)
    }
    
    /// Optimizes the canvas view for high resolution rendering.
    /// Call this on canvas creation to ensure stroke quality at all zoom levels.
    func optimizeForHighResolution() {
        // Get the resolution scale factor directly from ResolutionManager
        let scaleFactor = ResolutionManager.shared.resolutionScaleFactor
        
        // Apply the global resolution scale factor to content scale
        self.contentScaleFactor = UIScreen.main.scale * scaleFactor
        
        // Apply to layer as well for consistent scaling
        self.layer.contentsScale = UIScreen.main.scale * scaleFactor
        
        // Force high-resolution rendering with our scale factor
        self.layer.rasterizationScale = UIScreen.main.scale * scaleFactor
        
        // Disable rasterization since we want vector quality
        self.layer.shouldRasterize = false
        
        // Make sure the canvas view uses the display's native scale
        if let window = self.window {
            self.layer.contentsScale = window.screen.scale * scaleFactor
        }
        
        // For iOS 14+ we can use higher quality rendering policy
        if #available(iOS 14.0, *) {
            self.drawingPolicy = .pencilOnly // Highest quality rendering
            self.overrideUserInterfaceStyle = .light // Ensure consistent rendering
        }
        
        // Ensure child layers also use high resolution rendering
        optimizeLayerHierarchy(self.layer)
        
        // Force the layer to update
        self.setNeedsDisplay()
    }
    
    /// Legacy method for backward compatibility
    @available(*, deprecated, renamed: "optimizeForHighResolution")
    func optimizeForHighQualityZoom() {
        optimizeForHighResolution()
    }
    
    /// Recursively sets the contentsScale on a layer and its sublayers.
    private func optimizeLayerHierarchy(_ layer: CALayer) {
        // Get the resolution scale factor directly from ResolutionManager
        let scaleFactor = ResolutionManager.shared.resolutionScaleFactor
        
        // Set high resolution scale on this layer
        layer.contentsScale = UIScreen.main.scale * scaleFactor
        
        // Apply to all sublayers recursively
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                optimizeLayerHierarchy(sublayer)
            }
        }
    }
    
    /// Adjusts the canvas rendering quality based on the current zoom level.
    /// Call this from scrollViewDidZoom to optimize rendering at different zoom levels.
    func adjustQualityForZoom(_ zoomScale: CGFloat) {
        // Update the zoom scale in the coordinate manager
        CoordinateSpaceManager.shared.updateZoomScale(zoomScale)
        
        // Get resolution scale factor directly from ResolutionManager
        let resolutionFactor = ResolutionManager.shared.resolutionScaleFactor
        
        // Calculate the effective zoom considering our resolution scale factor
        let effectiveZoom = zoomScale * resolutionFactor
        
        // For very high zoom levels, ensure maximum quality
        if effectiveZoom > 2.0 {
            if #available(iOS 14.0, *) {
                self.drawingPolicy = .pencilOnly
            }
        } else {
            // For lower zoom levels, use standard quality which performs better
            if #available(iOS 14.0, *) {
                self.drawingPolicy = .anyInput
            }
        }
        
        // Force redraw with the new quality settings
        self.setNeedsDisplay()
    }
    
    /// Temporarily reduces rendering quality during active interactions
    /// Call this when beginning pan/zoom gestures and restore afterward
    func setTemporaryLowResolutionMode(_ enabled: Bool) {
        // Get resolution scale factor directly from ResolutionManager
        let resolutionFactor = ResolutionManager.shared.resolutionScaleFactor
        
        if enabled {
            // Store the current scale factor for restoration later
            let temporaryFactor = min(2.0, resolutionFactor)
            self.layer.contentsScale = UIScreen.main.scale * temporaryFactor
            
            // Lower rendering quality during interaction for better performance
            if #available(iOS 14.0, *) {
                self.drawingPolicy = .anyInput
            }
        } else {
            // Restore full resolution after interaction ends
            self.layer.contentsScale = UIScreen.main.scale * resolutionFactor
            
            // Restore quality based on current zoom
            if let scrollView = self.superview as? UIScrollView {
                adjustQualityForZoom(scrollView.zoomScale)
            } else {
                // Default back to high quality if not in a scroll view
                if #available(iOS 14.0, *) {
                    self.drawingPolicy = .pencilOnly
                }
            }
        }
        
        // Force redraw with new quality settings
        self.setNeedsDisplay()
    }
    
    /// Creates a higher resolution snapshot of the current visible area
    /// This can be used to create a higher quality view when needed
    func highResolutionSnapshot() -> UIImage? {
        // Get resolution scale factor directly from ResolutionManager
        let resolutionFactor = ResolutionManager.shared.resolutionScaleFactor
        
        // Create a renderer at our scaled resolution
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale * resolutionFactor
        
        let renderer = UIGraphicsImageRenderer(bounds: self.bounds, format: format)
        
        return renderer.image { context in
            self.layer.render(in: context.cgContext)
        }
    }
} 