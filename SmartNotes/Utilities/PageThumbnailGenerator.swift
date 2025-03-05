//
//  PageThumbnailGenerator.swift
//  SmartNotes
//
//  Created on 4/1/25.
//  This file generates thumbnail images from page drawing data for the page navigator.
//

import SwiftUI
import PencilKit

struct PageThumbnailGenerator {
    // Cache for generated thumbnails
    private static var thumbnailCache: [UUID: UIImage] = [:]
    
    // Default thumbnail size for the page navigator
    static let defaultSize = CGSize(width: 120, height: 160)
    
    /// Generates a thumbnail for a page
    /// - Parameters:
    ///   - page: The page model
    ///   - size: Size for the thumbnail
    ///   - force: Whether to force regeneration even if cached
    /// - Returns: UIImage thumbnail
    static func generateThumbnail(
        from page: Page,
        size: CGSize = defaultSize,
        force: Bool = false
    ) -> UIImage {
        
        // 1. Check if we have a cached thumbnail and aren't forcing regeneration
        if !force, let cachedImage = thumbnailCache[page.id] {
            return cachedImage
        }
        
        // 2. Check if there's any drawing data in the page
        if page.drawingData.isEmpty {
            let placeholder = createPlaceholderImage(for: page, size: size)
            thumbnailCache[page.id] = placeholder
            return placeholder
        }
        
        // 3. Decode the PKDrawing
        do {
            let drawing = try PKDrawing(data: page.drawingData)
            
            // 4. If no strokes, return a placeholder
            if drawing.strokes.isEmpty {
                let placeholder = createPlaceholderImage(for: page, size: size)
                thumbnailCache[page.id] = placeholder
                return placeholder
            }
            
            // Get the proper scaled page size that matches what's used in the app
            let pageRect = CGRect(
                origin: .zero,
                size: GlobalSettings.scaledPageSize
            )
            
            // Calculate scale to fit the entire page in the thumbnail while maintaining aspect ratio
            let scaleX = size.width / pageRect.width
            let scaleY = size.height / pageRect.height
            let scale = min(scaleX, scaleY)
            
            // Use a higher scale factor for better quality rendering, minimum 0.8
            let renderScale = max(scale * 2.0, 0.8)
            
            // Size for rendering the page in the thumbnail
            let scaledSize = CGSize(
                width: pageRect.width * scale,
                height: pageRect.height * scale
            )
            
            // Create a higher quality context for rendering
            // Use 3.0 scale factor for better quality on high-resolution displays
            UIGraphicsBeginImageContextWithOptions(
                size,
                true,
                3.0
            )
            
            // Fill background with white
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            
            // Calculate centered position
            let xOffset = (size.width - scaledSize.width) / 2
            let yOffset = (size.height - scaledSize.height) / 2
            
            // Get image from drawing of the entire page - using a higher quality render scale
            let drawingImage = drawing.image(
                from: pageRect,
                scale: renderScale
            )
            
            // Draw the image centered and scaled
            drawingImage.draw(in: CGRect(
                origin: CGPoint(x: xOffset, y: yOffset),
                size: scaledSize
            ))
            
            let result = UIGraphicsGetImageFromCurrentImageContext() ?? 
                createPlaceholderImage(for: page, size: size)
            UIGraphicsEndImageContext()
            
            // Cache the image
            thumbnailCache[page.id] = result
            return result
            
        } catch {
            print("Error converting drawing data: \(error)")
            let placeholder = createPlaceholderImage(for: page, size: size)
            thumbnailCache[page.id] = placeholder
            return placeholder
        }
    }
    
    /// Creates a placeholder image for a page
    /// - Parameters:
    ///   - page: The page model
    ///   - size: Size for the placeholder
    /// - Returns: UIImage placeholder
    static private func createPlaceholderImage(for page: Page, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 3.0)
        let context = UIGraphicsGetCurrentContext()
        
        // Fill with white background to represent a blank paper
        context?.setFillColor(UIColor.white.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        
        // Add a subtle page border/shadow to make it look like paper
        let pageRect = CGRect(origin: .zero, size: size)
        context?.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.1).cgColor)
        
        // Add very subtle lines to simulate paper texture
        context?.setStrokeColor(UIColor.gray.withAlphaComponent(0.05).cgColor)
        context?.setLineWidth(0.5)
        
        // Draw some barely visible horizontal lines for texture
        for y in stride(from: 10.0, to: size.height, by: 20.0) {
            context?.move(to: CGPoint(x: 5, y: y))
            context?.addLine(to: CGPoint(x: size.width - 5, y: y))
            context?.strokePath()
        }
        
        // Draw page number in the bottom corner, but more subtle
        let displayText = "\(page.pageNumber)"
        let font = UIFont.systemFont(ofSize: 10, weight: .light)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray.withAlphaComponent(0.4)
        ]
        
        let textSize = displayText.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: size.width - textSize.width - 8,
            y: size.height - textSize.height - 6,
            width: textSize.width,
            height: textSize.height
        )
        
        displayText.draw(in: textRect, withAttributes: textAttributes)
        
        // Draw bookmark if needed
        if page.isBookmarked {
            // Calculate position for bookmark icon (top right corner)
            let bookmarkRect = CGRect(x: size.width - 25, y: 5, width: 20, height: 20)
            
            // Draw a yellow bookmark icon
            context?.setFillColor(UIColor.systemYellow.cgColor)
            context?.move(to: CGPoint(x: bookmarkRect.minX, y: bookmarkRect.minY))
            context?.addLine(to: CGPoint(x: bookmarkRect.maxX, y: bookmarkRect.minY))
            context?.addLine(to: CGPoint(x: bookmarkRect.maxX, y: bookmarkRect.maxY))
            context?.addLine(to: CGPoint(x: bookmarkRect.midX, y: bookmarkRect.maxY - 5))
            context?.addLine(to: CGPoint(x: bookmarkRect.minX, y: bookmarkRect.maxY))
            context?.closePath()
            context?.fillPath()
        }
        
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return result
    }
    
    /// Clear the cache for a specific page or all pages
    static func clearCache(for pageID: UUID? = nil) {
        if let pageID = pageID {
            thumbnailCache.removeValue(forKey: pageID)
        } else {
            thumbnailCache.removeAll()
        }
    }
} 