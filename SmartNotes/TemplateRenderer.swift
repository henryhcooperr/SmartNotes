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
    
    /// Renders a template directly to the background of a PKCanvasView
    static func applyTemplateToCanvas(_ canvasView: PKCanvasView, template: CanvasTemplate,
                                     pageSize: CGSize, numberOfPages: Int, pageSpacing: CGFloat) {
        
        print("🖌️ TemplateRenderer: Applying template \(template.type.rawValue)")
        
        // First, set background color to white
        canvasView.backgroundColor = .white
        
        // If no template, we're done
        if template.type == .none {
            return
        }
        
        // Calculate the total canvas height
        let totalHeight = CGFloat(numberOfPages) * (pageSize.height + pageSpacing) - pageSpacing
        
        // Create a background image context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: canvasView.bounds.width, height: totalHeight), false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            print("🖌️ Failed to create graphics context")
            return
        }
        
        // Fill with white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: canvasView.bounds.width, height: totalHeight))
        
        // Set up drawing parameters
        context.setStrokeColor(template.color.cgColor)
        context.setLineWidth(template.lineWidth)
        
        // Draw the template pattern for each page
        for pageIndex in 0..<numberOfPages {
            let pageTop = CGFloat(pageIndex) * (pageSize.height + pageSpacing)
            let pageRect = CGRect(x: 0, y: pageTop, width: canvasView.bounds.width, height: pageSize.height)
            
            drawTemplateForPage(context: context, pageRect: pageRect, template: template)
        }
        
        // Get the image
        if let renderedImage = UIGraphicsGetImageFromCurrentImageContext() {
            UIGraphicsEndImageContext()
            
            // Create a background view with the template image
            let backgroundView = UIImageView(image: renderedImage)
            backgroundView.tag = 888 // Special tag for template background
            
            // Remove any existing background
            for subview in canvasView.subviews {
                if subview.tag == 888 {
                    subview.removeFromSuperview()
                }
            }
            
            // Add background view below canvas content
            canvasView.insertSubview(backgroundView, at: 0)
            
            print("🖌️ Template applied successfully")
        } else {
            UIGraphicsEndImageContext()
            print("🖌️ Failed to render template image")
        }
    }
    
    private static func drawTemplateForPage(context: CGContext, pageRect: CGRect, template: CanvasTemplate) {
        let spacing = template.spacing
        
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
                    let dotSize = template.lineWidth * 2
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
