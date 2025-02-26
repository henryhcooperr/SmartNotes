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
    
    static func generateThumbnail(
        from note: Note,
        size: CGSize = CGSize(width: 300, height: 200)
    ) -> UIImage {
        
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
        
        // 3. Decode the PKDrawing
        do {
            let drawing = try PKDrawing(data: note.drawingData)
            
            // Debug logs
            print("🖌️ Thumbnail debug: stroke count =", drawing.strokes.count)
            print("🖌️ Thumbnail debug: drawing.bounds =", drawing.bounds)
            
            // 4. If no strokes, return a placeholder
            guard !drawing.strokes.isEmpty else {
                let placeholder = createPlaceholderImage(size: size, title: note.title)
                thumbnailCache[note.id] = placeholder
                return placeholder
            }
            
            // --- FORCE FIRST-PAGE RECT (8.5" x 11") ---
            let firstPageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
            
            // 5. Figure out the scale so it fits in our thumbnail size
            let scale = min(
                size.width / firstPageRect.width,
                size.height / firstPageRect.height
            )
            
            // 6. Compute how big it will be once scaled down
            let thumbnailRect = CGRect(
                x: 0,
                y: 0,
                width: firstPageRect.width * scale,
                height: firstPageRect.height * scale
            )
            
            // 7. Render the drawing from the forced first-page rect
            let renderedImage = drawing.image(from: firstPageRect, scale: scale)
            
            // 8. Draw the rendered image centered into our final thumbnail
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            let context = UIGraphicsGetCurrentContext()
            
            // Fill background with white
            context?.setFillColor(UIColor.white.cgColor)
            context?.fill(CGRect(origin: .zero, size: size))
            
            // Center it
            let drawX = (size.width - thumbnailRect.width) / 2
            let drawY = (size.height - thumbnailRect.height) / 2
            renderedImage.draw(in: CGRect(
                x: drawX,
                y: drawY,
                width: thumbnailRect.width,
                height: thumbnailRect.height
            ))
            
            // 9. Get final image
            let result = UIGraphicsGetImageFromCurrentImageContext()
                ?? createPlaceholderImage(size: size, title: note.title)
            UIGraphicsEndImageContext()
            
            // Cache and return
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

extension Image {
    /// A custom initializer that calls SwiftUI's built-in `init(uiImage:)`.
    /// We rename it slightly to avoid recursion issues.
    init(fromUIImage uiImage: UIImage) {
        self.init(uiImage: uiImage)
    }
}
