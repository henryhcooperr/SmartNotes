//
//  DrawingTool.swift
//  SmartNotes
//
//  Created on 3/10/25.
//

import SwiftUI
import PencilKit

struct DrawingTool: Identifiable, Equatable, Codable {
    let id = UUID()
    var type: ToolType
    
    // For encoding/decoding purposes
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    enum ToolType: String, Codable {
        // Drawing tools
        case pen
        case pencil
        case marker
        
        // Utility tools
        case eraser
        case colorPicker
        case widthPicker
        case undo
        case redo
        
        // New advanced tools
        case selection  // For selecting and moving content
        case aiTool     // For AI-powered features
        
        var iconName: String {
            switch self {
            case .pen: return "pencil.tip"
            case .pencil: return "pencil"
            case .marker: return "highlighter"
            case .eraser: return "eraser"
            case .colorPicker: return "circle.fill"
            case .widthPicker: return "lineweight"
            case .undo: return "arrow.uturn.backward"
            case .redo: return "arrow.uturn.forward"
            case .selection: return "lasso.sparkles"
            case .aiTool: return "wand.and.stars"
            }
        }
        
        var requiresColor: Bool {
            switch self {
            case .pen, .pencil, .marker:
                return true
            default:
                return false
            }
        }
        
        var requiresWidth: Bool {
            switch self {
            case .pen, .pencil, .marker, .eraser:
                return true
            default:
                return false
            }
        }
    }
    
    // Optional stored properties for PKInkingTool type conversion
    func toPKTool(color: UIColor, width: CGFloat) -> PKTool {
        switch type {
        case .pen:
            return PKInkingTool(.pen, color: color, width: width)
        case .pencil:
            return PKInkingTool(.pencil, color: color, width: width)
        case .marker:
            return PKInkingTool(.marker, color: color, width: width)
        case .eraser:
            return PKEraserTool(.vector)
        case .selection:
            // For now, return the lasso tool if available, otherwise default to pen
            if #available(iOS 14.0, *) {
                return PKLassoTool()
            } else {
                return PKInkingTool(.pen, color: color, width: width)
            }
        case .aiTool:
            // AI tool will just be a visual placeholder for now
            // Return a pen with a different color to indicate it's special
            return PKInkingTool(.pen, color: UIColor.purple, width: width)
        default:
            return PKInkingTool(.pen, color: color, width: width)
        }
    }
} 