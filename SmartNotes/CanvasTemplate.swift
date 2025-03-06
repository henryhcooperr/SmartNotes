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
import UIKit
import Foundation

// Model for storing canvas template settings
public struct CanvasTemplate: Codable, Equatable {
    public enum TemplateType: String, CaseIterable, Identifiable, Codable {
        case none = "None"
        case lined = "Lined Paper"
        case graph = "Graph Paper"
        case dotted = "Dotted Paper"
        
        public var id: String { self.rawValue }
        
        public var iconName: String {
            switch self {
            case .none: return "doc"
            case .lined: return "doc.text"
            case .graph: return "square.grid.2x2"
            case .dotted: return "circle.grid.2x2"
            }
        }
    }
    
    public var type: TemplateType = .none
    
    // Base spacing value before scaling
    public private(set) var baseSpacing: CGFloat = 24 // Default spacing in points
    
    public var colorHex: String = "#CCCCCC" // Light gray in hex
    
    // Base line width value before scaling
    public private(set) var baseLineWidth: CGFloat = 0.5
    
    // Computed property for spacing that accounts for the resolution scale factor
    public var spacing: CGFloat {
        get {
            // Cap the resolution factor to prevent issues with extremely high values
            let safeResolutionFactor = min(ResolutionManager.shared.resolutionScaleFactor, 4.0)
            let result = baseSpacing * safeResolutionFactor
            
            if GlobalSettings.debugModeEnabled {
                print("🐞 Template spacing calculation: \(baseSpacing) × \(safeResolutionFactor) = \(result)")
            }
            
            return result
        }
        set {
            if ResolutionManager.shared.resolutionScaleFactor > 0 {
                baseSpacing = newValue / ResolutionManager.shared.resolutionScaleFactor
                if GlobalSettings.debugModeEnabled {
                    print("🐞 Setting base spacing to \(baseSpacing) from \(newValue)")
                }
            } else {
                baseSpacing = newValue
                print("⚠️ Warning: Resolution scale factor is 0, using raw value for spacing")
            }
        }
    }
    
    // Computed property for line width that accounts for the resolution scale factor
    public var lineWidth: CGFloat {
        get {
            // Cap the resolution factor to prevent issues with extremely high values
            let safeResolutionFactor = min(ResolutionManager.shared.resolutionScaleFactor, 4.0)
            let result = baseLineWidth * safeResolutionFactor
            
            if GlobalSettings.debugModeEnabled {
                print("🐞 Template line width calculation: \(baseLineWidth) × \(safeResolutionFactor) = \(result)")
            }
            
            return result
        }
        set {
            if ResolutionManager.shared.resolutionScaleFactor > 0 {
                baseLineWidth = newValue / ResolutionManager.shared.resolutionScaleFactor
                if GlobalSettings.debugModeEnabled {
                    print("🐞 Setting base line width to \(baseLineWidth) from \(newValue)")
                }
            } else {
                baseLineWidth = newValue
                print("⚠️ Warning: Resolution scale factor is 0, using raw value for line width")
            }
        }
    }
    
    // Helper to convert hex to UIColor
    public var color: UIColor {
        let parsedColor = UIColor(hex: colorHex) ?? .lightGray
        
        // In debug mode, log the color
        if GlobalSettings.debugModeEnabled {
            print("🐞 Template color from hex \(colorHex): \(parsedColor.debugDescription)")
        }
        
        return parsedColor
    }
    
    // Predefined templates
    public static let none = CanvasTemplate(type: .none)
    public static let lined = CanvasTemplate(type: .lined, baseSpacing: 24, colorHex: "#CCCCCC")
    public static let graph = CanvasTemplate(type: .graph, baseSpacing: 20, colorHex: "#CCCCCC")
    public static let dotted = CanvasTemplate(type: .dotted, baseSpacing: 20, colorHex: "#CCCCCC")
    
    // Init with base values
    public init(type: TemplateType = .none, baseSpacing: CGFloat = 24, colorHex: String = "#CCCCCC", baseLineWidth: CGFloat = 0.5) {
        self.type = type
        self.baseSpacing = baseSpacing
        self.colorHex = colorHex
        self.baseLineWidth = baseLineWidth
    }
    
    // Coding keys for Codable conformance
    public enum CodingKeys: String, CodingKey {
        case type, baseSpacing, colorHex, baseLineWidth
        
        // Add legacy keys for backward compatibility
        case spacing, lineWidth
    }
    
    // Custom decoder to support older versions that used spacing and lineWidth
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode template type
        type = try container.decode(TemplateType.self, forKey: .type)
        
        // Decode color hex - handle possible missing value with default
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#CCCCCC"
        
        // Try to decode baseSpacing, but fall back to spacing if needed
        if let spacing = try? container.decode(CGFloat.self, forKey: .baseSpacing) {
            baseSpacing = spacing
        } else if let spacing = try? container.decode(CGFloat.self, forKey: .spacing) {
            // Legacy code path
            baseSpacing = spacing
        }
        // Default value if neither key exists
        
        // Try to decode baseLineWidth, but fall back to lineWidth if needed
        if let lineWidth = try? container.decode(CGFloat.self, forKey: .baseLineWidth) {
            baseLineWidth = lineWidth
        } else if let lineWidth = try? container.decode(CGFloat.self, forKey: .lineWidth) {
            // Legacy code path
            baseLineWidth = lineWidth
        }
        // Default value if neither key exists
    }
    
    // Custom encoder to store values with new keys
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(baseSpacing, forKey: .baseSpacing)
        try container.encode(baseLineWidth, forKey: .baseLineWidth)
    }
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
