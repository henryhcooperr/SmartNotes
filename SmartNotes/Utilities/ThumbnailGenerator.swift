//
//  ThumbnailGenerator.swift
//  SmartNotes
//
//  Created on 2/25/25.
//
//  This file generates thumbnail images from note drawing data.
//  Key responsibilities:
//    - Rendering PKDrawing data to UIImage thumbnails
//    - Caching thumbnails for performance
//    - Creating placeholder images for empty notes
//    - Handling drawing data conversion errors
//
//  These thumbnails are used in the NotePreviewsGrid and NotePreviewCard
//  views to show note content in the UI.
//

import SwiftUI
import PencilKit

struct ThumbnailGenerator {
    // Cache for generated thumbnails
    private static var thumbnailCache: [UUID: UIImage] = [:]
    
    static func generateThumbnail(
        from note: Note,
        size: CGSize = CGSize(width: 300, height: 200),
        highQuality: Bool = true
    ) -> UIImage {
        
        print("🖼️ Generating thumbnail for note: \(note.id)")
        
        // 1. Check if we have a cached thumbnail
        if let cachedImage = thumbnailCache[note.id] {
            print("🖼️ Using cached thumbnail")
            return cachedImage
        }
        
        // 2. Check if there's any drawing data in the note (either in pages or legacy field)
        let hasLegacyContent = !note.drawingData.isEmpty
        let hasPageContent = !note.pages.isEmpty && note.pages.first?.drawingData.isEmpty == false
        let hasContent = hasLegacyContent || hasPageContent
        
        print("🖼️ Note has legacy content: \(hasLegacyContent)")
        print("🖼️ Note has page content: \(hasPageContent)")
        print("🖼️ Note pages count: \(note.pages.count)")
        
        if !hasContent {
            print("🖼️ No content found, creating placeholder")
            let placeholder = createPlaceholderImage(size: size, title: note.title)
            thumbnailCache[note.id] = placeholder
            return placeholder
        }
        
        // 3. Try to get drawing data from the first page (new structure) or fall back to note.drawingData (legacy)
        let drawingData: Data
        if hasPageContent {
            drawingData = note.pages[0].drawingData
            print("🖼️ Using drawing data from first page: \(drawingData.count) bytes")
        } else {
            drawingData = note.drawingData
            print("🖼️ Using legacy drawing data: \(drawingData.count) bytes")
        }
        
        // 4. Decode the PKDrawing
        do {
            let drawing = try PKDrawing(data: drawingData)
            
            // Debug logs
            print("🖼️ Stroke count: \(drawing.strokes.count)")
            if !drawing.strokes.isEmpty {
                print("🖼️ Drawing bounds: \(drawing.bounds)")
            }
            
            // 5. If no strokes, return a placeholder
            if drawing.strokes.isEmpty {
                print("🖼️ Drawing has no strokes, creating placeholder")
                let placeholder = createPlaceholderImage(size: size, title: note.title)
                thumbnailCache[note.id] = placeholder
                return placeholder
            }
            
            // Define the standard page size (8.5" x 11" at 72 DPI)
            let standardPageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
            
            // QUALITY IMPROVEMENT: Generate at 2x the requested size for higher quality
            let targetSize = CGSize(
                width: size.width * (highQuality ? 2.0 : 1.0),
                height: size.height * (highQuality ? 2.0 : 1.0)
            )
            
            // Calculate scale based on aspect ratio
            let scale = min(
                targetSize.width / standardPageRect.width,
                targetSize.height / standardPageRect.height
            )
            
            // QUALITY IMPROVEMENT: Use a higher scale factor
            let renderScale: CGFloat = highQuality ? max(scale, 0.4) : scale
            
            // Render the drawing with white background
            UIGraphicsBeginImageContextWithOptions(targetSize, true, 0)
            
            // Fill background with white
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            
            // Calculate centered position
            let drawingSize = CGSize(
                width: standardPageRect.width * renderScale,
                height: standardPageRect.height * renderScale
            )
            
            let xOffset = (targetSize.width - drawingSize.width) / 2
            let yOffset = (targetSize.height - drawingSize.height) / 2
            
            // Render the drawing
            drawing.image(
                from: standardPageRect,
                scale: renderScale
            ).draw(in: CGRect(origin: CGPoint(x: xOffset, y: yOffset), size: drawingSize))
            
            let result = UIGraphicsGetImageFromCurrentImageContext() ?? 
                createPlaceholderImage(size: targetSize, title: note.title)
            UIGraphicsEndImageContext()
            
            // Cache the higher quality image
            thumbnailCache[note.id] = result
            return result
            
        } catch {
            print("Error converting drawing data: \(error)")
            let placeholder = createPlaceholderImage(size: size, title: note.title)
            thumbnailCache[note.id] = placeholder
            return placeholder
        }
    }
    
    static private func createPlaceholderImage(size: CGSize, title: String) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        
        // Fill with light gray background
        context?.setFillColor(UIColor.systemGray6.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        
        // Draw a placeholder text with the note title
        let displayTitle = title.isEmpty ? "Untitled Note" : title
        let font = UIFont.systemFont(ofSize: 16)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray
        ]
        
        let textSize = displayTitle.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        displayTitle.draw(in: textRect, withAttributes: textAttributes)
        
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return result
    }
    
    // Clear the cache for a specific note or all notes
    static func clearCache(for noteID: UUID? = nil) {
        if let noteID = noteID {
            thumbnailCache.removeValue(forKey: noteID)
        } else {
            thumbnailCache.removeAll()
        }
    }
    
    // Invalidate the thumbnail for a specific note
    static func invalidateThumbnail(for noteID: UUID) {
        thumbnailCache.removeValue(forKey: noteID)
        print("🖼️ Thumbnail cache invalidated for note: \(noteID)")
    }
    
    // Clears all cached thumbnails - use sparingly
    static func clearAllCaches() {
        thumbnailCache.removeAll()
        print("🧹 All thumbnail caches cleared")
    }
}

extension Image {
    /// A custom initializer that calls SwiftUI's built-in `init(uiImage:)`.
    /// We rename it slightly to avoid recursion issues.
    init(fromUIImage uiImage: UIImage) {
        self.init(uiImage: uiImage)
    }
}
