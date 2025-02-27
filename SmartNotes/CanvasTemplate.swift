//
//  CanvasTemplate.swift
//  SmartNotes
//
//  Created on 2/26/25.
//
//  This file defines the template options for note backgrounds.
//  Templates include:
//    - None (blank paper)
//    - Lined (horizontal lines)
//    - Graph (grid lines)
//    - Dotted (dot grid)
//
//  Each template has configurable properties:
//    - Type (from the enum)
//    - Spacing between lines/dots
//    - Color (stored as hex string)
//    - Line width
//
//  The file also includes a UIColor extension for hex color conversion.
//

import SwiftUI

// Model for storing canvas template settings
struct CanvasTemplate: Codable, Equatable {
    enum TemplateType: String, CaseIterable, Identifiable, Codable {
        case none = "None"
        case lined = "Lined Paper"
        case graph = "Graph Paper"
        case dotted = "Dotted Paper"
        
        var id: String { self.rawValue }
        
        var iconName: String {
            switch self {
            case .none: return "doc"
            case .lined: return "doc.text"
            case .graph: return "square.grid.2x2"
            case .dotted: return "circle.grid.2x2"
            }
        }
    }
    
    var type: TemplateType = .none
    var spacing: CGFloat = 24 // Default spacing in points
    var colorHex: String = "#CCCCCC" // Light gray in hex
    var lineWidth: CGFloat = 0.5
    
    // Helper to convert hex to UIColor
    var color: UIColor {
        UIColor(hex: colorHex) ?? .lightGray
    }
    
    // Predefined templates
    static let none = CanvasTemplate(type: .none)
    static let lined = CanvasTemplate(type: .lined, spacing: 24, colorHex: "#CCCCCC")
    static let graph = CanvasTemplate(type: .graph, spacing: 20, colorHex: "#CCCCCC")
    static let dotted = CanvasTemplate(type: .dotted, spacing: 20, colorHex: "#CCCCCC")
}

// Extension to convert between UIColor and hex strings
extension UIColor {
    convenience init?(hex: String) {
        let r, g, b: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    
                    self.init(red: r, green: g, blue: b, alpha: 1.0)
                    return
                }
            }
        }
        
        return nil
    }
    
    func toHex() -> String {
        guard let components = self.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
