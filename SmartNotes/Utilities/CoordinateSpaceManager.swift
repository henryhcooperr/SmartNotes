//
//  CoordinateSpaceManager.swift
//  SmartNotes
//
//  Created on 3/5/25
//
//  This file contains the CoordinateSpaceManager class that centralizes 
//  all coordinate transformation logic across different coordinate spaces.
//  Key responsibilities:
//    - Defining standard coordinate spaces used throughout the app
//    - Providing methods to convert between coordinate spaces
//    - Handling resolution scaling consistently
//    - Supporting page positioning calculations
//

import UIKit
import CoreGraphics
import PencilKit

/// Defines the different coordinate spaces used throughout the app
enum CoordinateSpace {
    /// Raw screen coordinates at device resolution (device pixels)
    case screen
    
    /// Coordinates within the scrollView (considering contentOffset but not zoom)
    case scrollView
    
    /// Coordinates within the container view that holds all pages
    case container
    
    /// Coordinates on a specific canvas/page (affected by position in container)
    case canvas(pageIndex: Int)
    
    /// Drawing coordinates (scaled by resolution factor for high quality)
    case drawing
}

/// Manager class responsible for handling all coordinate transformations
class CoordinateSpaceManager {
    // MARK: - Singleton Access
    
    /// Shared instance for app-wide access
    static let shared = CoordinateSpaceManager()
    
    // Private initialization prevents multiple instances
    private init() {}
    
    // MARK: - Properties
    
    /// Current zoom scale of the scroll view
    private var currentZoomScale: CGFloat = 1.0
    
    /// Page size in points (unscaled)
    var pageSize: CGSize {
        return GlobalSettings.standardPageSize
    }
    
    /// Page size after applying resolution scaling
    var scaledPageSize: CGSize {
        return GlobalSettings.scaledPageSize
    }
    
    /// Spacing between pages
    var pageSpacing: CGFloat {
        return 12 * GlobalSettings.resolutionScaleFactor
    }
    
    /// Total height of a page including spacing
    var totalPageHeight: CGFloat {
        return scaledPageSize.height + pageSpacing
    }
    
    /// The resolution scale factor from global settings
    var resolutionScaleFactor: CGFloat {
        return GlobalSettings.resolutionScaleFactor
    }
    
    // MARK: - Zoom Management
    
    /// Update the current zoom scale
    /// - Parameter zoomScale: The new zoom scale to use for calculations
    func updateZoomScale(_ zoomScale: CGFloat) {
        guard zoomScale > 0 else {
            print("⚠️ CoordinateSpaceManager: Attempted to set invalid zoom scale: \(zoomScale)")
            return
        }
        
        self.currentZoomScale = zoomScale
        
        if GlobalSettings.debugModeEnabled {
            print("🔍 CoordinateSpaceManager: Zoom scale updated to \(zoomScale)")
        }
    }
    
    // MARK: - Page Position Calculations
    
    /// Get the Y position for a specific page in container coordinates
    /// - Parameter pageIndex: Index of the page (0-based)
    /// - Returns: Y position of the top of the page in container coordinates
    func pageYPositionInContainer(pageIndex: Int) -> CGFloat {
        return CGFloat(pageIndex) * totalPageHeight
    }
    
    /// Get the center Y position for a specific page in container coordinates
    /// - Parameter pageIndex: Index of the page (0-based)
    /// - Returns: Y position of the center of the page in container coordinates
    func pageCenterYInContainer(pageIndex: Int) -> CGFloat {
        return pageYPositionInContainer(pageIndex: pageIndex) + (scaledPageSize.height / 2)
    }
    
    /// Calculate the scroll offset needed to center a page in the visible area
    /// - Parameters:
    ///   - pageIndex: Index of the page to center
    ///   - scrollView: The scroll view containing the pages
    ///   - container: The container view holding all pages
    /// - Returns: The content offset to use for centering the page
    func scrollOffsetToCenter(pageIndex: Int, scrollView: UIScrollView, container: UIView) -> CGPoint {
        // Calculate the target page's center point in container coordinates
        let targetCenterInContainer = CGPoint(
            x: container.bounds.width / 2,
            y: pageCenterYInContainer(pageIndex: pageIndex)
        )
        
        // Convert the point to scroll view coordinates
        let targetPointInScroll = container.convert(targetCenterInContainer, to: scrollView)
        
        // Calculate the offset needed to center this point in the scroll view
        let proposedOffsetY = targetPointInScroll.y - (scrollView.bounds.height / 2)
        
        // Ensure we don't scroll beyond content bounds
        let maxPossibleOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let newOffsetY = min(max(0, proposedOffsetY), maxPossibleOffsetY)
        
        // Keep the X offset unchanged
        return CGPoint(x: scrollView.contentOffset.x, y: newOffsetY)
    }
    
    /// Determine which page is visible at a given scroll position
    /// - Parameters:
    ///   - scrollView: The scroll view containing the pages
    ///   - container: The container view holding all pages
    ///   - totalPages: Total number of pages
    /// - Returns: The index of the most visible page
    func determineVisiblePageIndex(
        scrollView: UIScrollView,
        container: UIView,
        totalPages: Int
    ) -> Int {
        // Get the visible rect in container coordinates
        let visibleRect = scrollView.convert(scrollView.bounds, to: container)
        
        // Default to first page if we can't determine
        guard totalPages > 0 else { return 0 }
        
        // Calculate which page is most visible
        let visibleCenterY = visibleRect.midY
        
        // Convert to page index
        let rawIndex = visibleCenterY / totalPageHeight
        let pageIndex = max(0, min(totalPages - 1, Int(rawIndex)))
        
        return pageIndex
    }
    
    // MARK: - Container Centering
    
    /// Calculate insets to center container in scroll view
    /// - Parameters:
    ///   - scrollView: The scroll view containing the container
    ///   - container: The container to center
    /// - Returns: Content insets to apply
    func calculateCenteringInsets(scrollView: UIScrollView, container: UIView) -> UIEdgeInsets {
        let offsetX = max((scrollView.bounds.width - container.frame.width * scrollView.zoomScale) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - container.frame.height * scrollView.zoomScale) * 0.5, 0)
        
        return UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
    
    // MARK: - Coordinate Conversions
    
    /// Convert a point from one coordinate space to another
    /// - Parameters:
    ///   - point: The point to convert
    ///   - from: Source coordinate space
    ///   - to: Target coordinate space
    ///   - scrollView: The scroll view (required for some conversions)
    ///   - container: The container view (required for some conversions)
    /// - Returns: The converted point
    func convertPoint(
        _ point: CGPoint,
        from: CoordinateSpace,
        to: CoordinateSpace,
        scrollView: UIScrollView? = nil,
        container: UIView? = nil
    ) -> CGPoint {
        // First convert from source to container space
        let containerPoint: CGPoint
        
        switch from {
        case .screen:
            guard let scrollView = scrollView else {
                fatalError("ScrollView required to convert from screen coordinates")
            }
            containerPoint = scrollView.convert(point, to: container)
            
        case .scrollView:
            guard let container = container else {
                fatalError("Container required to convert from scrollView coordinates")
            }
            containerPoint = scrollView?.convert(point, to: container) ?? point
            
        case .container:
            containerPoint = point
            
        case .canvas(let pageIndex):
            // Calculate the offset to add based on page position
            let pageOffset = pageYPositionInContainer(pageIndex: pageIndex)
            containerPoint = CGPoint(x: point.x, y: point.y + pageOffset)
            
        case .drawing:
            // Scale down by resolution factor
            containerPoint = CGPoint(
                x: point.x / resolutionScaleFactor,
                y: point.y / resolutionScaleFactor
            )
        }
        
        // Then convert from container space to target
        switch to {
        case .screen:
            guard let scrollView = scrollView, let container = container else {
                fatalError("ScrollView and Container required to convert to screen coordinates")
            }
            return container.convert(containerPoint, to: scrollView.superview)
            
        case .scrollView:
            guard let scrollView = scrollView, let container = container else {
                fatalError("ScrollView and Container required to convert to scrollView coordinates")
            }
            return container.convert(containerPoint, to: scrollView)
            
        case .container:
            return containerPoint
            
        case .canvas(let pageIndex):
            // Calculate the offset to remove based on page position
            let pageOffset = pageYPositionInContainer(pageIndex: pageIndex)
            return CGPoint(x: containerPoint.x, y: containerPoint.y - pageOffset)
            
        case .drawing:
            // Scale up by resolution factor
            return CGPoint(
                x: containerPoint.x * resolutionScaleFactor,
                y: containerPoint.y * resolutionScaleFactor
            )
        }
    }
    
    /// Convert a size from one coordinate space to another
    /// - Parameters:
    ///   - size: The size to convert
    ///   - from: Source coordinate space
    ///   - to: Target coordinate space
    /// - Returns: The converted size
    func convertSize(
        _ size: CGSize,
        from: CoordinateSpace,
        to: CoordinateSpace
    ) -> CGSize {
        // Most coordinate spaces maintain the same size, except for
        // resolution scaling between container and drawing spaces
        
        switch (from, to) {
        case (.drawing, _):
            // Scale down from drawing to any other space
            return CGSize(
                width: size.width / resolutionScaleFactor,
                height: size.height / resolutionScaleFactor
            )
            
        case (_, .drawing):
            // Scale up to drawing space
            return CGSize(
                width: size.width * resolutionScaleFactor,
                height: size.height * resolutionScaleFactor
            )
            
        default:
            // No size conversion needed between other spaces
            return size
        }
    }
    
    /// Convert a rect from one coordinate space to another
    /// - Parameters:
    ///   - rect: The rect to convert
    ///   - from: Source coordinate space
    ///   - to: Target coordinate space
    ///   - scrollView: The scroll view (required for some conversions)
    ///   - container: The container view (required for some conversions)
    /// - Returns: The converted rect
    func convertRect(
        _ rect: CGRect,
        from: CoordinateSpace,
        to: CoordinateSpace,
        scrollView: UIScrollView? = nil,
        container: UIView? = nil
    ) -> CGRect {
        let convertedOrigin = convertPoint(
            rect.origin,
            from: from,
            to: to,
            scrollView: scrollView,
            container: container
        )
        
        let convertedSize = convertSize(rect.size, from: from, to: to)
        
        return CGRect(origin: convertedOrigin, size: convertedSize)
    }
    
    // MARK: - Resolution Scaling Helpers
    
    /// Apply resolution scaling to a value
    /// - Parameter value: Value to scale
    /// - Returns: Scaled value
    func applyResolutionScaling(to value: CGFloat) -> CGFloat {
        return value * resolutionScaleFactor
    }
    
    /// Remove resolution scaling from a value
    /// - Parameter value: Value to unscale
    /// - Returns: Unscaled value
    func removeResolutionScaling(from value: CGFloat) -> CGFloat {
        return value / resolutionScaleFactor
    }
    
    /// Apply resolution scaling to a point
    /// - Parameter point: Point to scale
    /// - Returns: Scaled point
    func applyResolutionScaling(to point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * resolutionScaleFactor,
            y: point.y * resolutionScaleFactor
        )
    }
    
    /// Remove resolution scaling from a point
    /// - Parameter point: Point to unscale
    /// - Returns: Unscaled point
    func removeResolutionScaling(from point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x / resolutionScaleFactor,
            y: point.y / resolutionScaleFactor
        )
    }
    
    /// Apply resolution scaling to a size
    /// - Parameter size: Size to scale
    /// - Returns: Scaled size
    func applyResolutionScaling(to size: CGSize) -> CGSize {
        return CGSize(
            width: size.width * resolutionScaleFactor,
            height: size.height * resolutionScaleFactor
        )
    }
    
    /// Remove resolution scaling from a size
    /// - Parameter size: Size to unscale
    /// - Returns: Unscaled size
    func removeResolutionScaling(from size: CGSize) -> CGSize {
        return CGSize(
            width: size.width / resolutionScaleFactor,
            height: size.height / resolutionScaleFactor
        )
    }
    
    /// Apply resolution scaling to a rect
    /// - Parameter rect: Rect to scale
    /// - Returns: Scaled rect
    func applyResolutionScaling(to rect: CGRect) -> CGRect {
        return CGRect(
            x: rect.origin.x * resolutionScaleFactor,
            y: rect.origin.y * resolutionScaleFactor,
            width: rect.width * resolutionScaleFactor,
            height: rect.height * resolutionScaleFactor
        )
    }
    
    /// Remove resolution scaling from a rect
    /// - Parameter rect: Rect to unscale
    /// - Returns: Unscaled rect
    func removeResolutionScaling(from rect: CGRect) -> CGRect {
        return CGRect(
            x: rect.origin.x / resolutionScaleFactor,
            y: rect.origin.y / resolutionScaleFactor,
            width: rect.width / resolutionScaleFactor,
            height: rect.height / resolutionScaleFactor
        )
    }
    
    // MARK: - Debug Helpers
    
    /// Log detailed information about coordinate conversion for debugging
    /// - Parameters:
    ///   - point: The point being converted
    ///   - from: Source coordinate space
    ///   - to: Target coordinate space
    ///   - result: The result of the conversion
    func logConversion(
        point: CGPoint,
        from: CoordinateSpace,
        to: CoordinateSpace,
        result: CGPoint
    ) {
        guard GlobalSettings.debugModeEnabled else { return }
        
        let fromSpace = spaceDescription(from)
        let toSpace = spaceDescription(to)
        
        print("🔄 Coordinate conversion: (\(Int(point.x)),\(Int(point.y))) in \(fromSpace) -> (\(Int(result.x)),\(Int(result.y))) in \(toSpace)")
    }
    
    /// Get a description of a coordinate space for debugging
    /// - Parameter space: The coordinate space
    /// - Returns: A string description
    private func spaceDescription(_ space: CoordinateSpace) -> String {
        switch space {
        case .screen:
            return "screen"
        case .scrollView:
            return "scrollView"
        case .container:
            return "container"
        case .canvas(let pageIndex):
            return "canvas(page \(pageIndex + 1))"
        case .drawing:
            return "drawing"
        }
    }
}

// MARK: - UIView Extensions

extension UIView {
    /// Convert a point from a specific coordinate space to view coordinates
    /// - Parameters:
    ///   - point: The point to convert
    ///   - from: The source coordinate space
    ///   - scrollView: The scroll view (required for some conversions)
    ///   - container: The container view (required for some conversions)
    /// - Returns: The converted point in view coordinates
    func convertFrom(
        _ point: CGPoint,
        from coordinateSpace: CoordinateSpace,
        scrollView: UIScrollView? = nil,
        container: UIView? = nil
    ) -> CGPoint {
        // First determine which view coordinate space we're in
        let toSpace: CoordinateSpace
        
        if self is PKCanvasView {
            // For canvas views, use their position in the container to determine page index
            if let containerView = container,
               let multiPageScrollView = scrollView as? MultiPageScrollView,
               !multiPageScrollView.pages.isEmpty {
                
                // Find the canvas position in the container
                let canvasFrame = self.convert(self.bounds, to: containerView)
                let canvasY = canvasFrame.midY
                
                // Use position to estimate page index
                let totalPageHeight = CoordinateSpaceManager.shared.totalPageHeight
                let estimatedPageIndex = max(0, min(multiPageScrollView.pages.count - 1, Int(canvasY / totalPageHeight)))
                
                toSpace = .canvas(pageIndex: estimatedPageIndex)
            } else {
                // Fall back to container if we can't determine page
                toSpace = .container
            }
        } else if self == container {
            toSpace = .container
        } else if self == scrollView {
            toSpace = .scrollView
        } else {
            // Default to screen for other views
            toSpace = .screen
        }
        
        return CoordinateSpaceManager.shared.convertPoint(
            point,
            from: coordinateSpace,
            to: toSpace,
            scrollView: scrollView,
            container: container
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Notification sent when coordinate spaces change (e.g., zoom change)
    static let coordinateSpaceChanged = Notification.Name("CoordinateSpaceChanged")
} 