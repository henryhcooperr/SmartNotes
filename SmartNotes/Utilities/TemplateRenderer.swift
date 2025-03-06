//
//  TemplateRenderer.swift
//  SmartNotes
//
//  Created on 2/25/25.
//
//  This file handles rendering templates onto the canvas background.
//  Key responsibilities:
//    - Converting template settings to visual elements
//    - Creating template images using Core Graphics
//    - Applying templates to PKCanvasView using layers
//    - Handling multiple rendering approaches for compatibility
//    - Debugging template application issues
//
//  This is a utility class used by TemplateCanvasView to apply
//  templates to the drawing surface.
//

import UIKit
import SwiftUI
import PencilKit

class TemplateRenderer {
    
    // Cache for template images to avoid redrawing
    private static var templateImageCache: [String: UIImage] = [:]
    
    // Generate a cache key based on template properties
    private static func cacheKeyFor(
        template: CanvasTemplate,
        width: CGFloat,
        height: CGFloat,
        numberOfPages: Int
    ) -> String {
        return "\(template.type.rawValue)_\(template.spacing)_\(template.lineWidth)_\(template.colorHex)_\(width)x\(height)_\(numberOfPages)"
    }
    
    /// Calculate safe drawing size
    private static func calculateSafeDrawingSize(
        canvasView: PKCanvasView,
        pageSize: CGSize,
        numberOfPages: Int,
        pageSpacing: CGFloat
    ) -> CGSize {
        // Get the coordinate manager for resolution scaling
        let coordManager = CoordinateSpaceManager.shared
        
        // Apply safe limits to prevent memory issues on large drawings
        let safeWidth = min(canvasView.frame.width, 2000 * coordManager.resolutionScaleFactor)
        
        let totalHeight = (CGFloat(numberOfPages) * pageSize.height)
                        + (CGFloat(numberOfPages - 1) * pageSpacing)
        let safeHeight = min(totalHeight, 10_000 * coordManager.resolutionScaleFactor)
        
        return CGSize(width: safeWidth, height: safeHeight)
    }
    
    /// A revised template rendering approach that uses CALayer for better integration
    static func applyTemplateToCanvas(
        _ canvasView: PKCanvasView,
        template: CanvasTemplate,
        pageSize: CGSize,
        numberOfPages: Int,
        pageSpacing: CGFloat
    ) {
        // Force clear the cache if debug mode is on to ensure template changes are applied
        if GlobalSettings.debugModeEnabled {
            print("🐞 Debug mode: Forcing template refresh")
            clearTemplateCache()
        }
        
        // Logs the file/line/function for better debugging
        print(
            "🖌️ TemplateRenderer: [\(extractFileName(#file)):\(#line)] [\(#function)] " +
            "Applying template \(template.type.rawValue)"
        )
        
        // Validate dimensions
        guard canvasView.frame.width > 0, canvasView.frame.height > 0 else {
            print("🖌️ TemplateRenderer: Invalid canvas dimensions (\(canvasView.frame.size)), deferring template application")
            // If the frame is 0,0, try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyTemplateToCanvas(
                    canvasView,
                    template: template,
                    pageSize: pageSize,
                    numberOfPages: numberOfPages,
                    pageSpacing: pageSpacing
                )
                debugTemplateState(canvasView, template: template)
            }
            return
        }
        
        // Always remove existing templates first to start fresh
        removeExistingTemplate(from: canvasView)
        
        // If template is .none, just set a white background and exit
        if template.type == .none {
            canvasView.backgroundColor = .white
            print("🖌️ Template type is .none, setting white background only")
            return
        }
        
        // Get the coordinate manager for resolution scaling
        let coordManager = CoordinateSpaceManager.shared
        
        // Calculate safe drawing size using the new helper method
        let safeSize = calculateSafeDrawingSize(
            canvasView: canvasView,
            pageSize: pageSize,
            numberOfPages: numberOfPages,
            pageSpacing: pageSpacing
        )
        
        // Get template caching setting
        let useCache = UserDefaults.standard.bool(forKey: "useTemplateCaching")
        
        print("🖌️ Template details: type=\(template.type.rawValue), spacing=\(template.spacing), lineWidth=\(template.lineWidth)")
        print("🖌️ Canvas dimensions: \(canvasView.frame.size), zoomScale=\(canvasView.layer.contentsScale)")
        
        // Generate the cache key
        let cacheKey = cacheKeyFor(
            template: template,
            width: safeSize.width,
            height: safeSize.height,
            numberOfPages: numberOfPages
        )
        
        let templateImage: UIImage
        
        // Use cached image if available and caching is enabled
        if useCache, let cachedImage = templateImageCache[cacheKey] {
            templateImage = cachedImage
            print("🖌️ Using cached template image for key: \(cacheKey)")
        } else {
            // Generate the image (either because caching is disabled or no cached image exists)
            print("🖌️ Generating new template image...")
            PerformanceMonitor.shared.startOperation("Template generation")
            
            guard let newImage = createTemplateImage(
                template: template,
                width: safeSize.width,
                height: safeSize.height,
                pageSize: pageSize,
                numberOfPages: numberOfPages,
                pageSpacing: pageSpacing
            ) else {
                print("🖌️ Failed to create template image")
                PerformanceMonitor.shared.endOperation("Template generation")
                return
            }
            
            templateImage = newImage
            PerformanceMonitor.shared.endOperation("Template generation")
            
            // Cache the template image for reuse if caching is enabled
            if useCache {
                templateImageCache[cacheKey] = templateImage
                print("🖌️ Cached new template image with key: \(cacheKey)")
            }
        }
        
        // Always use the complex approach for now to ensure templates are visible
        // This is more reliable than the simple approach
        applyComplexTemplate(
            to: canvasView,
            image: templateImage,
            width: safeSize.width,
            height: safeSize.height
        )
        
        // After applying, debug the state
        if GlobalSettings.debugModeEnabled {
            debugTemplateState(canvasView, template: template)
        }
        
        print("🖌️ Template application complete")
    }
    
    /// Calculates template complexity (0.0-1.0) to determine rendering approach
    private static func calculateTemplateComplexity(
        template: CanvasTemplate,
        width: CGFloat,
        height: CGFloat
    ) -> CGFloat {
        switch template.type {
        case .none:
            return 0.0
        case .lined:
            // Complexity based on line count
            let lineCount = height / template.spacing
            return min(0.3, lineCount / 100.0)
        case .graph:
            // Higher complexity due to both vertical and horizontal lines
            let lineCount = (height / template.spacing) + (width / template.spacing)
            return min(0.7, lineCount / 200.0)
        case .dotted:
            // Highest complexity due to many dots
            let dotCount = (height / template.spacing) * (width / template.spacing)
            return min(1.0, dotCount / 10000.0)
        }
    }
    
    /// Fast approach for simple templates
    private static func applySimpleTemplate(
        to canvasView: PKCanvasView,
        image: UIImage,
        width: CGFloat,
        height: CGFloat
    ) {
        // Just set background color for simplicity and performance
        canvasView.backgroundColor = UIColor(patternImage: image)
    }
    
    /// More robust approach for complex templates
    private static func applyComplexTemplate(
        to canvasView: PKCanvasView,
        image: UIImage,
        width: CGFloat,
        height: CGFloat
    ) {
        print("🖌️ Applying complex template with image size: \(image.size)")
        
        // Get the coordinate manager for resolution scaling
        let coordManager = CoordinateSpaceManager.shared
        
        // ENSURE PREVIOUS TEMPLATES ARE COMPLETELY REMOVED
        removeExistingTemplate(from: canvasView)
        
        // APPROACH 1: Use CALayer with explicit z-position
        let templateLayer = CALayer()
        templateLayer.name = "TemplateLayer"
        templateLayer.contents = image.cgImage
        templateLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        // Use high-resolution content scale from coordinate manager
        templateLayer.contentsScale = UIScreen.main.scale * coordManager.resolutionScaleFactor
        
        // CRITICAL FIX: Use a very low z-position to ensure it's behind everything
        templateLayer.zPosition = -1000
        
        // Insert at index 0 to ensure it's at the back
        canvasView.layer.insertSublayer(templateLayer, at: 0)
        print("🖌️ Added template CALayer with z-position \(templateLayer.zPosition)")
        
        // APPROACH 2: Add a UIImageView behind everything else
        let backgroundView = UIImageView(image: image)
        backgroundView.tag = 888
        backgroundView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        backgroundView.contentMode = .topLeft
        
        // Set high resolution content scale from coordinate manager
        backgroundView.contentScaleFactor = UIScreen.main.scale * coordManager.resolutionScaleFactor
        
        canvasView.insertSubview(backgroundView, at: 0)
        print("🖌️ Added template UIImageView at subview index 0")
        
        // APPROACH 3: Also set background pattern as fallback
        canvasView.backgroundColor = UIColor(patternImage: image)
        
        // Force layout update
        canvasView.setNeedsLayout()
        canvasView.layoutIfNeeded()
    }
    
    /// Clears template cache to free memory
    static func clearTemplateCache() {
        print("🧹 Template image cache cleared")
        templateImageCache.removeAll()
        
        // Force garbage collection to free up memory
        #if DEBUG
        print("🧹 Forcing memory cleanup")
        autoreleasepool {
            // Empty autorelease pool to help free memory
        }
        #endif
    }
    
    /// Utility to extract just the filename from a file path
    private static func extractFileName(_ filePath: String) -> String {
        // #file might look like "/Users/.../TemplateRenderer.swift"
        // So we split on "/" and grab the last piece
        let components = filePath.split(separator: "/")
        return components.last.map(String.init) ?? filePath
    }
    
    /// Helper method to remove existing template layers
    private static func removeExistingTemplate(from canvasView: PKCanvasView) {
        var templatesRemoved = 0
        
        // Remove any previous template layers
        if let sublayers = canvasView.layer.sublayers {
            for layer in sublayers where layer.name == "TemplateLayer" {
                layer.removeFromSuperlayer()
                templatesRemoved += 1
            }
        }
        
        // Remove any template subviews
        var subviewsRemoved = 0
        for subview in canvasView.subviews where subview.tag == 888 {
            subview.removeFromSuperview()
            subviewsRemoved += 1
        }
        
        if templatesRemoved > 0 || subviewsRemoved > 0 {
            print("🖌️ Removed \(templatesRemoved) template layers and \(subviewsRemoved) template subviews")
        }
    }
    
    /// Creates the lined/graph/dotted image for all pages stacked vertically
    private static func createTemplateImage(
        template: CanvasTemplate,
        width: CGFloat,
        height: CGFloat,
        pageSize: CGSize,
        numberOfPages: Int,
        pageSpacing: CGFloat
    ) -> UIImage? {
        // Create a new bitmap context with high resolution
        // The last parameter (0) means use the scale of the main screen,
        // but we'll manually set it higher to match our resolution factor
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: width, height: height),
            true,
            UIScreen.main.scale * GlobalSettings.resolutionScaleFactor
        )
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // Fill the entire context with white
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Set line color and width, scaled by our resolution factor
        context.setStrokeColor(template.color.cgColor)
        context.setFillColor(template.color.cgColor)
        context.setLineWidth(template.lineWidth * GlobalSettings.resolutionScaleFactor)
        
        // Make sure spacing is reasonable and scale by our resolution factor
        let spacing = max(min(template.spacing, 100), 10) * GlobalSettings.resolutionScaleFactor
        
        // For each page, draw the lines/dots
        for i in 0..<numberOfPages {
            let pageTop = CGFloat(i) * (pageSize.height + pageSpacing)
            if pageTop >= height { break }
            
            let pageRect = CGRect(
                x: 0,
                y: pageTop,
                width: width,
                height: min(pageSize.height, height - pageTop)
            )
            
            switch template.type {
            case .lined:
                // Draw horizontal lines starting from the page edge
                for y in stride(from: pageRect.minY, to: pageRect.maxY, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: pageRect.minX, y: y))
                    context.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                    context.strokePath()
                }
                
            case .graph:
                // Draw horizontal lines starting from the page edge
                for y in stride(from: pageRect.minY, to: pageRect.maxY, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: pageRect.minX, y: y))
                    context.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                    context.strokePath()
                }
                // Draw vertical lines starting from the page edge
                for x in stride(from: pageRect.minX, to: pageRect.maxX, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: x, y: pageRect.minY))
                    context.addLine(to: CGPoint(x: x, y: pageRect.maxY))
                    context.strokePath()
                }
                
            case .dotted:
                // Draw dots starting from the page edge
                for y in stride(from: pageRect.minY, to: pageRect.maxY, by: spacing) {
                    for x in stride(from: pageRect.minX, to: pageRect.maxX, by: spacing) {
                        let dotSize = max(min(template.lineWidth * 2, 5), 1) * GlobalSettings.resolutionScaleFactor
                        let dotRect = CGRect(
                            x: x - dotSize / 2,
                            y: y - dotSize / 2,
                            width: dotSize,
                            height: dotSize
                        )
                        context.fillEllipse(in: dotRect)
                    }
                }
                
            case .none:
                // Do nothing, it's just blank
                break
            }
        }
        
        // Extract the final UIImage
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    /// Prints debug info about the current canvas
    static func debugTemplateState(_ canvasView: PKCanvasView, template: CanvasTemplate) {
        print("🔍 DEBUG TEMPLATE STATE:")
        print("  • Template type: \(template.type.rawValue)")
        print("  • Canvas dimensions: \(canvasView.frame.size)")
        print("  • Canvas background color: \(canvasView.backgroundColor?.description ?? "nil")")
        print("  • Subview count: \(canvasView.subviews.count)")
        
        // Check for existing template layers
        let templateLayers = canvasView.layer.sublayers?.filter { $0.name == "TemplateLayer" } ?? []
        print("  • Template layers: \(templateLayers.count)")
        
        // Check for template image views
        let templateViews = canvasView.subviews.filter { $0.tag == 888 }
        print("  • Template image views: \(templateViews.count)")
        
        // If there's at least one image view, log its size
        if let firstTemplateView = templateViews.first as? UIImageView {
            print("  • Template image size: \(firstTemplateView.image?.size ?? .zero)")
        }
    }
}
