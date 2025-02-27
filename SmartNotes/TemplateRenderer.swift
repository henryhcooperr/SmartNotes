import UIKit
import SwiftUI
import PencilKit

class TemplateRenderer {
    
    /// A completely revised template rendering approach that uses CALayer for better integration
    static func applyTemplateToCanvas(_ canvasView: PKCanvasView,
                                      template: CanvasTemplate,
                                      pageSize: CGSize,
                                      numberOfPages: Int,
                                      pageSpacing: CGFloat) {
        
        print("🖌️ TemplateRenderer: Applying template \(template.type.rawValue)")
        
        // Early validation of dimensions
        guard canvasView.frame.width > 0, canvasView.frame.height > 0 else {
            print("🖌️ TemplateRenderer: Invalid canvas dimensions (\(canvasView.frame.size)), deferring template application")
            // Set a timer to try again in 0.1 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyTemplateToCanvas(canvasView, template: template, pageSize: pageSize,
                                     numberOfPages: numberOfPages, pageSpacing: pageSpacing)
            
            // Add this to the end of applyTemplateToCanvas
            debugTemplateState(canvasView, template: template)
            }
            return
        }
        
        // First remove any existing template layer
        removeExistingTemplate(from: canvasView)
        
        // If template is 'none', just set background white and exit
        if template.type == .none {
            canvasView.backgroundColor = .white
            return
        }
        
        // Calculate dimensions
        let safeWidth = min(canvasView.frame.width, 2000)
        let totalHeight = CGFloat(numberOfPages) * pageSize.height +
                          CGFloat(numberOfPages - 1) * pageSpacing
        let safeHeight = min(totalHeight, 10000)
        
        // Create the template image
        guard let templateImage = createTemplateImage(template: template,
                                                    width: safeWidth,
                                                    height: safeHeight,
                                                    pageSize: pageSize,
                                                    numberOfPages: numberOfPages,
                                                    pageSpacing: pageSpacing) else {
            print("🖌️ Failed to create template image")
            canvasView.backgroundColor = .white
            return
        }
        
        // THREE DIFFERENT APPROACHES TO ENSURE TEMPLATE VISIBILITY:
        
        // APPROACH 1: Use CALayer for better layering behavior
        let templateLayer = CALayer()
        templateLayer.name = "TemplateLayer"
        templateLayer.contents = templateImage.cgImage
        templateLayer.frame = CGRect(x: 0, y: 0, width: safeWidth, height: safeHeight)
        templateLayer.zPosition = -100 // Force it to the back
        canvasView.layer.insertSublayer(templateLayer, at: 0)
        
        // APPROACH 2: Also add as a background view (belt and suspenders)
        let backgroundView = UIImageView(image: templateImage)
        backgroundView.tag = 888
        backgroundView.frame = CGRect(x: 0, y: 0, width: safeWidth, height: safeHeight)
        backgroundView.contentMode = .topLeft
        canvasView.insertSubview(backgroundView, at: 0)
        
        // APPROACH 3: Set background pattern color (third approach for maximum compatibility)
        canvasView.backgroundColor = UIColor(patternImage: templateImage)
        
        print("🖌️ Template applied using multiple rendering approaches")
    }
    
    private static func removeExistingTemplate(from canvasView: PKCanvasView) {
        // Remove any existing template layer
        if let sublayers = canvasView.layer.sublayers {
            for layer in sublayers {
                if layer.name == "TemplateLayer" {
                    layer.removeFromSuperlayer()
                }
            }
        }
        
        // Remove any existing template background view
        for subview in canvasView.subviews where subview.tag == 888 {
            subview.removeFromSuperview()
        }
    }
    
    private static func createTemplateImage(template: CanvasTemplate,
                                           width: CGFloat,
                                           height: CGFloat,
                                           pageSize: CGSize,
                                           numberOfPages: Int,
                                           pageSpacing: CGFloat) -> UIImage? {
        // Create image context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // Fill with white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Configure drawing attributes
        context.setStrokeColor(template.color.cgColor)
        context.setFillColor(template.color.cgColor)
        context.setLineWidth(template.lineWidth)
        
        // Use safe spacing value
        let spacing = max(min(template.spacing, 100), 10)
        
        // Draw template for each page
        for i in 0..<numberOfPages {
            let pageTop = CGFloat(i) * (pageSize.height + pageSpacing)
            if pageTop >= height { break }
            
            let pageRect = CGRect(
                x: 0,
                y: pageTop,
                width: width,
                height: min(pageSize.height, height - pageTop)
            )
            
            // Draw page template based on type
            switch template.type {
            case .lined:
                // Horizontal lines
                for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: pageRect.minX, y: y))
                    context.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                    context.strokePath()
                }
                
            case .graph:
                // Horizontal lines
                for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: pageRect.minX, y: y))
                    context.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                    context.strokePath()
                }
                
                // Vertical lines
                for x in stride(from: pageRect.minX + spacing, to: pageRect.maxX, by: spacing) {
                    context.beginPath()
                    context.move(to: CGPoint(x: x, y: pageRect.minY))
                    context.addLine(to: CGPoint(x: x, y: pageRect.maxY))
                    context.strokePath()
                }
                
            case .dotted:
                // Dots
                for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                    for x in stride(from: pageRect.minX + spacing, to: pageRect.maxX, by: spacing) {
                        let dotSize = max(min(template.lineWidth * 2, 5), 1)
                        let dotRect = CGRect(
                            x: x - dotSize/2,
                            y: y - dotSize/2,
                            width: dotSize,
                            height: dotSize
                        )
                        context.fillEllipse(in: dotRect)
                    }
                }
                
            case .none:
                break
            }
        }
        
        // Get the image and clean up
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
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
        
        if let firstTemplateView = templateViews.first as? UIImageView {
            print("  • Template image size: \(firstTemplateView.image?.size ?? .zero)")
        }
    }
}

