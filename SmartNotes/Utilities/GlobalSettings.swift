//
//  GlobalSettings.swift
//  SmartNotes
//
//  Created by Henry Cooper
//
//  This file contains global settings and constants for the entire app.
//  Key responsibilities:
//    - Providing a central location for app-wide configuration values
//    - Making configuration values accessible throughout the app
//    - Containing the resolution scale factor for high-quality drawing
//

import SwiftUI
import Foundation
import CoreGraphics

// MARK: - Global Settings
class GlobalSettings {
    // MARK: - Drawing Resolution
    
    /// The global resolution scale factor for all canvas-related operations.
    /// Increasing this value will improve drawing quality at higher zoom levels
    /// but may impact performance on lower-end devices.
    ///
    /// Values:
    /// - 1.0: Standard resolution (default before enhancement)
    /// - 2.0: Double resolution (good balance of quality and performance)
    /// - 3.0: Triple resolution (high quality but may affect performance)
    static let resolutionScaleFactor: CGFloat = 3.0
    
    // MARK: - Canvas Dimensions
    
    /// The standard page size for a single page in points (72 points per inch)
    /// This is equivalent to US Letter size (8.5" x 11") at 72 DPI
    /// After scaling, this will be multiplied by the resolutionScaleFactor
    static let standardPageSize = CGSize(width: 612, height: 792)
    
    /// The scaled page size after applying the resolution factor
    static var scaledPageSize: CGSize {
        return CGSize(
            width: standardPageSize.width * resolutionScaleFactor,
            height: standardPageSize.height * resolutionScaleFactor
        )
    }
    
    // MARK: - Zoom Settings
    
    /// The minimum zoom scale for scroll views, adjusted for resolution factor
    static var minimumZoomScale: CGFloat {
        return 0.25 / resolutionScaleFactor
    }
    
    /// The maximum zoom scale for scroll views, adjusted for resolution factor
    static var maximumZoomScale: CGFloat {
        return 5.0 / resolutionScaleFactor
    }
    
    /// The default initial zoom scale, adjusted to maintain the same view size
    static var defaultZoomScale: CGFloat {
        return 1.0 / resolutionScaleFactor
    }
} 
