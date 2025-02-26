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
    
    static func generateThumbnail(from note: Note, size: CGSize = CGSize(width: 300, height: 200)) -> UIImage {
        // Check if we have a cached thumbnail
        if let cachedImage = thumbnailCache[note.id] {
            return cachedImage
        }
        
        // If drawing data is empty, return a placeholder
        if note.drawingData.isEmpty {
            let placeholder = createPlaceholderImage(size: size, title: note.title)
            thumbnailCache[note.id] = placeholder
            return placeholder
        }
        
        // Create a drawing from the data
        let drawing = PKDrawing.fromData(note.drawingData)
        
        // If drawing is empty, return a placeholder
        if drawing.bounds.isEmpty {
            let placeholder = createPlaceholderImage(size: size, title: note.title)
            thumbnailCache[note.id] = placeholder
            return placeholder
        }
        
        // Determine the scale to fit the drawing into the thumbnail size
        let scale = min(
            size.width / max(drawing.bounds.width, 1),
            size.height / max(drawing.bounds.height, 1)
        )
        
        // Create an image from the drawing
        let thumbnailRect = CGRect(
            x: 0,
            y: 0,
            width: min(drawing.bounds.width * scale, size.width),
            height: min(drawing.bounds.height * scale, size.height)
        )
        
        // Render drawing to an image with proper scaling
        let renderedImage = drawing.image(from: drawing.bounds, scale: scale)
        
        // Create a context and draw the image centered in our thumbnail size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        
        // Fill the background with white
        context?.setFillColor(UIColor.white.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        
        // Center the image in the thumbnail
        let drawX = (size.width - thumbnailRect.width) / 2
        let drawY = (size.height - thumbnailRect.height) / 2
        
        renderedImage.draw(in: CGRect(x: drawX, y: drawY, width: thumbnailRect.width, height: thumbnailRect.height))
        
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? createPlaceholderImage(size: size, title: note.title)
        UIGraphicsEndImageContext()
        
        // Cache the result
        thumbnailCache[note.id] = result
        
        return result
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
