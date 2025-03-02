//
//  ToolbarPosition.swift
//  SmartNotes
//
//  Created on 3/10/25.
//

import SwiftUI

enum ToolbarPosition: String, CaseIterable, Codable {
    case bottom
    case left
    case right
    case top
    
    var alignment: Alignment {
        switch self {
        case .bottom: return .bottom
        case .top: return .top
        case .left: return .leading
        case .right: return .trailing
        }
    }
    
    var isVertical: Bool {
        return self == .left || self == .right
    }
    
    // Calculate the snap positions for dragging
    func snapPositions(in geometry: GeometryProxy) -> [CGPoint] {
        let width = geometry.size.width
        let height = geometry.size.height
        
        return [
            CGPoint(x: width / 2, y: 0), // top
            CGPoint(x: width / 2, y: height), // bottom
            CGPoint(x: 0, y: height / 2), // left
            CGPoint(x: width, y: height / 2) // right
        ]
    }
    
    // Find the nearest position from a dragged point
    static func nearest(to point: CGPoint, in geometry: GeometryProxy) -> ToolbarPosition {
        let size = geometry.size
        let _ = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Calculate distances to each edge
        let topDist = abs(point.y)
        let bottomDist = abs(point.y - size.height)
        let leftDist = abs(point.x)
        let rightDist = abs(point.x - size.width)
        
        // Find minimum distance
        let minDist = min(topDist, bottomDist, leftDist, rightDist)
        
        if minDist == topDist {
            return .top
        } else if minDist == bottomDist {
            return .bottom
        } else if minDist == leftDist {
            return .left
        } else {
            return .right
        }
    }
} 