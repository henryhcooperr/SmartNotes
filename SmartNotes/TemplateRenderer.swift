//
//  TemplateRenderer.swift
//  SmartNotes
//
//  Created on 2/26/25.
//

import UIKit
import SwiftUI
import PencilKit

class TemplateRenderer {
    
    /// Renders a template directly to the background of a PKCanvasView with strict validation
    static func applyTemplateToCanvas(_ canvasView: PKCanvasView, template: CanvasTemplate,
                                     pageSize: CGSize, numberOfPages: Int, pageSpacing: CGFloat) {
        
        print("🖌️ TemplateRenderer: Applying template \(template.type.rawValue)")
        
        // Validate all input dimensions to prevent invalid geometry
        guard canvasView.frame.width > 0, canvasView.frame.height > 0,
              pageSize.width > 0, pageSize.height > 0,
              numberOfPages > 0, pageSpacing >= 0,
              !canvasView.frame.width.isNaN, !canvasView.frame.height.isNaN else {
            print("🖌️ TemplateRenderer: Skipping due to invalid dimensions")
            canvasView.backgroundColor = .white // Fallback to white
            return
        }
        
        // If no template, set white background and early return
        if template.type == .none {
            canvasView.backgroundColor = .white
            return
        }
        
        // Calculate safe total height
        let totalHeight = CGFloat(numberOfPages) * pageSize.height +
                          CGFloat(numberOfPages - 1) * pageSpacing
        
        // Create background image with explicit, validated dimensions
        let safeWidth = min(canvasView.frame.width, 2000) // Ensure reasonable width limit
        let safeHeight = min(totalHeight, 5000) // Ensure reasonable height limit
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: safeWidth, height: safeHeight), true, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            print("🖌️ Failed to create graphics context")
            canvasView.backgroundColor = .white
            return
        }
        
        // Fill white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: safeWidth, height: safeHeight))
        
        // Set up drawing parameters
        context.setStrokeColor(template.color.cgColor)
        context.setLineWidth(template.lineWidth)
        context.setFillColor(template.color.cgColor)
        
        // Draw template for each page
        for i in 0..<numberOfPages {
            let pageTop = CGFloat(i) * (pageSize.height + pageSpacing)
            // Skip if this page is beyond our safe height
            if pageTop >= safeHeight { continue }
            
            let pageRect = CGRect(
                x: 0,
                y: pageTop,
                width: safeWidth,
                height: min(pageSize.height, safeHeight - pageTop)
            )
            
            // Draw template elements for this page
            drawTemplateForPage(context: context, pageRect: pageRect, template: template)
        }
        
        // Get the rendered image
        if let templateImage = UIGraphicsGetImageFromCurrentImageContext() {
            UIGraphicsEndImageContext()
            
            // Clear any existing template layers
            for subview in canvasView.subviews where subview.tag == 888 {
                subview.removeFromSuperview()
            }
            
            // Create and add template image view
            let imageView = UIImageView(image: templateImage)
            imageView.tag = 888
            imageView.frame = CGRect(x: 0, y: 0, width: safeWidth, height: safeHeight)
            canvasView.insertSubview(imageView, at: 0)
            
            // Make canvas transparent to see template
            canvasView.backgroundColor = .clear
            
            print("🖌️ Template applied successfully")
        } else {
            UIGraphicsEndImageContext()
            print("🖌️ Failed to render template image")
            canvasView.backgroundColor = .white // Fallback
        }
    }
    
    private static func drawTemplateForPage(context: CGContext, pageRect: CGRect, template: CanvasTemplate) {
        // Use safe spacing value (prevent extremely small or large values)
        let spacing = max(min(template.spacing, 100), 10)
        
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
                    let dotSize = max(min(template.lineWidth * 2, 5), 1) // Safe dot size
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
}

