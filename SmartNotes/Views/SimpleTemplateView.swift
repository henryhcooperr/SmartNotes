import SwiftUI

/// A SwiftUI-based template background that renders
/// lines or dots for the requested number of pages.
struct SimpleTemplateView: View {
    let template: CanvasTemplate
    let pageSize: CGSize
    let numberOfPages: Int
    let pageSpacing: CGFloat
    
    // Calculate the total height of all pages combined
    private var totalHeight: CGFloat {
        CGFloat(numberOfPages) * (pageSize.height + pageSpacing) - pageSpacing
    }
    
    var body: some View {
        // We use a GeometryReader so we can adapt the width
        // to whatever space it’s given (e.g., screen width).
        GeometryReader { geometry in
            let width = geometry.size.width
            
            // Stack a background color (optional) and a Canvas for drawing
            ZStack(alignment: .top) {
                // Replace .white with .clear if you want the overall background transparent
                Color.white
                
                Canvas { context, size in
                    // If the user chooses 'none,' don't draw lines
                    guard template.type != .none else { return }
                    
                    // Convert template color (UIColor) to a SwiftUI Color
                    let lineColor = Color(template.color)
                    // Configure stroke style with the user’s chosen line width
                    let strokeStyle = StrokeStyle(lineWidth: template.lineWidth)
                    
                    // Draw for each page index
                    for pageIndex in 0..<numberOfPages {
                        let pageTop = CGFloat(pageIndex) * (pageSize.height + pageSpacing)
                        let pageRect = CGRect(x: 0,
                                              y: pageTop,
                                              width: width,
                                              height: pageSize.height)
                        
                        switch template.type {
                        case .lined:
                            // Horizontal lines
                            for y in stride(from: pageRect.minY,
                                            to: pageRect.maxY,
                                            by: template.spacing) {
                                var path = Path()
                                path.move(to: CGPoint(x: pageRect.minX, y: y))
                                path.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                                context.stroke(path,
                                               with: .color(lineColor),
                                               style: strokeStyle)
                            }
                            
                        case .graph:
                            // Horizontal lines
                            for y in stride(from: pageRect.minY,
                                            to: pageRect.maxY,
                                            by: template.spacing) {
                                var path = Path()
                                path.move(to: CGPoint(x: pageRect.minX, y: y))
                                path.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                                context.stroke(path,
                                               with: .color(lineColor),
                                               style: strokeStyle)
                            }
                            // Vertical lines
                            for x in stride(from: pageRect.minX,
                                            to: pageRect.maxX,
                                            by: template.spacing) {
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: pageRect.minY))
                                path.addLine(to: CGPoint(x: x, y: pageRect.maxY))
                                context.stroke(path,
                                               with: .color(lineColor),
                                               style: strokeStyle)
                            }
                            
                        case .dotted:
                            // Dots
                            for y in stride(from: pageRect.minY,
                                            to: pageRect.maxY,
                                            by: template.spacing) {
                                for x in stride(from: pageRect.minX,
                                                to: pageRect.maxX,
                                                by: template.spacing) {
                                    let dotDiameter = template.lineWidth * 2
                                    let dotRect = CGRect(
                                        x: x - (dotDiameter / 2),
                                        y: y - (dotDiameter / 2),
                                        width: dotDiameter,
                                        height: dotDiameter
                                    )
                                    var dotPath = Path(ellipseIn: dotRect)
                                    // Fill for dotted
                                    context.fill(dotPath, with: .color(lineColor))
                                }
                            }
                            
                        case .none:
                            // Do nothing
                            break
                        }
                    }
                }
            }
            .frame(width: width, height: totalHeight, alignment: .top)
        }
    }
}
