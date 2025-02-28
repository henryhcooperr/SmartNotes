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
    
    /// A revised template rendering approach that uses CALayer for better integration
    static func applyTemplateToCanvas(
        _ canvasView: PKCanvasView,
        template: CanvasTemplate,
        pageSize: CGSize,
        numberOfPages: Int,
        pageSpacing: CGFloat
    ) {
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
        
        // Remove any existing template layers or background
        removeExistingTemplate(from: canvasView)
        
        // If template is .none, just set a white background and exit
        if template.type == .none {
            canvasView.backgroundColor = .white
            return
        }
        
        // Calculate safe drawing size
        let safeWidth = min(canvasView.frame.width, 2000)
        let totalHeight = (CGFloat(numberOfPages) * pageSize.height)
                        + (CGFloat(numberOfPages - 1) * pageSpacing)
        let safeHeight = min(totalHeight, 10_000)
        
        // Build the template image
        guard let templateImage = createTemplateImage(
            template: template,
            width: safeWidth,
            height: safeHeight,
            pageSize: pageSize,
            numberOfPages: numberOfPages,
            pageSpacing: pageSpacing
        ) else {
            print("🖌️ Failed to create template image")
            return
        }
        
        // APPROACH 1: Use CALayer
        let templateLayer = CALayer()
        templateLayer.name = "TemplateLayer"
        templateLayer.contents = templateImage.cgImage
        templateLayer.frame = CGRect(x: 0, y: 0, width: safeWidth, height: safeHeight)
        templateLayer.zPosition = -100
        canvasView.layer.insertSublayer(templateLayer, at: 0)
        
        // APPROACH 2: Also add an image subview behind the drawing
        let backgroundView = UIImageView(image: templateImage)
        backgroundView.tag = 888
        backgroundView.frame = CGRect(x: 0, y: 0, width: safeWidth, height: safeHeight)
        backgroundView.contentMode = .topLeft
        canvasView.insertSubview(backgroundView, at: 0)
        
        // APPROACH 3: Set a background pattern color
        canvasView.backgroundColor = UIColor(patternImage: templateImage)
        
        print("🖌️ Template applied using multiple rendering approaches")
    }
    
    /// Utility to extract just the filename from a file path
    private static func extractFileName(_ filePath: String) -> String {
        // #file might look like "/Users/.../TemplateRenderer.swift"
        // So we split on "/" and grab the last piece
        let components = filePath.split(separator: "/")
        return components.last.map(String.init) ?? filePath
    }
    
    /// Removes previously drawn layers and background images
    private static func removeExistingTemplate(from canvasView: PKCanvasView) {
        // Remove any existing CALayer named "TemplateLayer"
        if let sublayers = canvasView.layer.sublayers {
            for layer in sublayers {
                if layer.name == "TemplateLayer" {
                    layer.removeFromSuperlayer()
                }
            }
        }
        
        // Remove any existing background subview tagged 888
        for subview in canvasView.subviews where subview.tag == 888 {
            subview.removeFromSuperview()
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
        // Create a new bitmap context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // Fill the entire context with white
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Set line color and width
        context.setStrokeColor(template.color.cgColor)
        context.setFillColor(template.color.cgColor)
        context.setLineWidth(template.lineWidth)
        
        // Make sure spacing is reasonable
        let spacing = max(min(template.spacing, 100), 10)
        
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
                // Draw horizontal lines
                for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: pageRect.minX, y: y))
                    context.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                    context.strokePath()
                }
                
            case .graph:
                // Draw horizontal lines
                for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: pageRect.minX, y: y))
                    context.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                    context.strokePath()
                }
                // Draw vertical lines
                for x in stride(from: pageRect.minX + spacing, to: pageRect.maxX, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: x, y: pageRect.minY))
                    context.addLine(to: CGPoint(x: x, y: pageRect.maxY))
                    context.strokePath()
                }
                
            case .dotted:
                // Draw dots
                for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                    for x in stride(from: pageRect.minX + spacing, to: pageRect.maxX, by: spacing) {
                        let dotSize = max(min(template.lineWidth * 2, 5), 1)
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
