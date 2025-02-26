//
//  SimpleTemplateView.swift
//  SmartNotes
//
//  Created on 2/26/25.
//

import SwiftUI

struct SimpleTemplateView: View {
    var template: CanvasTemplate
    var pageSize: CGSize
    var numberOfPages: Int
    var pageSpacing: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // Calculate canvas width
                let canvasWidth = min(size.width, pageSize.width)
                
                // Set up drawing parameters
                let color = Color(template.color)
                let lineWidth = template.lineWidth
                let spacing = template.spacing
                
                // Draw for each page
                for pageIndex in 0..<numberOfPages {
                    let pageTop = CGFloat(pageIndex) * (pageSize.height + pageSpacing)
                    let pageRect = CGRect(
                        x: (size.width - canvasWidth) / 2,  // Center horizontally
                        y: pageTop,
                        width: canvasWidth,
                        height: pageSize.height
                    )
                    
                    // Skip if template is none
                    if template.type == .none {
                        continue
                    }
                    
                    // Draw the template based on type
                    switch template.type {
                    case .lined:
                        // Horizontal lines
                        for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                            let linePath = Path { path in
                                path.move(to: CGPoint(x: pageRect.minX, y: y))
                                path.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                            }
                            context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
                        }
                        
                    case .graph:
                        // Horizontal lines
                        for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                            let linePath = Path { path in
                                path.move(to: CGPoint(x: pageRect.minX, y: y))
                                path.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                            }
                            context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
                        }
                        
                        // Vertical lines
                        for x in stride(from: pageRect.minX + spacing, to: pageRect.maxX, by: spacing) {
                            let linePath = Path { path in
                                path.move(to: CGPoint(x: x, y: pageRect.minY))
                                path.addLine(to: CGPoint(x: x, y: pageRect.maxY))
                            }
                            context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
                        }
                        
                    case .dotted:
                        // Dots at intersections
                        for y in stride(from: pageRect.minY + spacing, to: pageRect.maxY, by: spacing) {
                            for x in stride(from: pageRect.minX + spacing, to: pageRect.maxX, by: spacing) {
                                let dotSize = CGSize(width: lineWidth * 2, height: lineWidth * 2)
                                let dotRect = CGRect(
                                    x: x - dotSize.width/2,
                                    y: y - dotSize.height/2,
                                    width: dotSize.width,
                                    height: dotSize.height
                                )
                                let dotPath = Path(ellipseIn: dotRect)
                                context.fill(dotPath, with: .color(color))
                            }
                        }
                        
                    case .none:
                        break
                    }
                }
            }
            .background(Color.white)
        }
    }
}
