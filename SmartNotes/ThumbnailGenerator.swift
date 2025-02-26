//
//  ThumbnailGenerator.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI
import PencilKit

struct ThumbnailGenerator {
    // Cache for generated thumbnails
    private static var thumbnailCache: [UUID: UIImage] = [:]
    
    static func generateThumbnail(from note: Note,
                                 size: CGSize = CGSize(width: 300, height: 200)) -> UIImage {
        // 1. Check if we have a cached thumbnail
        if let cachedImage = thumbnailCache[note.id] {
            return cachedImage
        }
        
        // 2. If drawing data is empty, return a placeholder
        if note.drawingData.isEmpty {
            let placeholder = createPlaceholderImage(size: size, title: note.title)
            thumbnailCache[note.id] = placeholder
            return placeholder
        }
        
        do {
            // 3. Create a PKDrawing from the data
            let drawing = try PKDrawing(data: note.drawingData)
            
            // 4. Additional check for any strokes at all
            guard !drawing.strokes.isEmpty else {
                let placeholder = createPlaceholderImage(size: size, title: note.title)
                thumbnailCache[note.id] = placeholder
                return placeholder
            }
            
            // 5. Get the bounding rect; if it's empty (or huge), fall back to a standard page size
            var boundingRect = drawing.bounds
            if boundingRect.isEmpty || boundingRect.height > 3000 {
                // Fallback: standard 8.5" x 11" at 72 DPI = 612 x 792
                boundingRect = CGRect(x: 0, y: 0, width: 612, height: 792)
            }
            
            // 6. Calculate the scale so the boundingRect fits into our desired thumbnail size
            let boundingWidth = max(boundingRect.width, 1)
            let boundingHeight = max(boundingRect.height, 1)
            let scale = min(size.width / boundingWidth, size.height / boundingHeight)
            
            // 7. Figure out how big the scaled‐down bounding rect will be
            let thumbnailRect = CGRect(
                x: 0,
                y: 0,
                width: min(boundingWidth * scale, size.width),
                height: min(boundingHeight * scale, size.height)
            )
            
            // 8. Render the drawing as a UIImage using the clamped boundingRect
            let renderedImage = drawing.image(from: boundingRect, scale: scale)
            
            // 9. Create a final context (the "canvas" for our thumbnail)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            let context = UIGraphicsGetCurrentContext()
            
            // 10. Fill the context background with white
            context?.setFillColor(UIColor.white.cgColor)
            context?.fill(CGRect(origin: .zero, size: size))
            
            // 11. Center the rendered image in our thumbnail context
            let drawX = (size.width - thumbnailRect.width) / 2
            let drawY = (size.height - thumbnailRect.height) / 2
            renderedImage.draw(in: CGRect(x: drawX, y: drawY,
                                          width: thumbnailRect.width,
                                          height: thumbnailRect.height))
            
            // 12. Extract the final image
            let result = UIGraphicsGetImageFromCurrentImageContext()
                         ?? createPlaceholderImage(size: size, title: note.title)
            UIGraphicsEndImageContext()
            
            // 13. Cache the result before returning
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
}

// SwiftUI Image extension to use a UIImage
extension Image {
    init(uiImage: UIImage) {
        self.init(uiImage: uiImage)
    }
}
