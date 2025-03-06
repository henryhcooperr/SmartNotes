//
//  Note.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  This file defines the Note data model, which represents an individual note
//  that users can create and edit. Each note has:
//    - A unique ID
//    - A title (can be empty)
//    - Drawing data (binary data containing the PKDrawing)
//    - Creation and modification timestamps
//
//  It also includes extension helpers for PKDrawing to convert between
//  drawing objects and binary data for storage.
//

import SwiftUI
import PencilKit

struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var drawingData: Data
    var dateCreated: Date = Date()
    var lastModified: Date = Date()
    
    var pages: [Page] = []
    
    var noteTemplate: CanvasTemplate?
    // Simplified hash function that only uses ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Simplified equality check
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Creates a copy of this note with specified properties changed while preserving others
    /// This is important for immutable state updates in the EventStore
    func copyWith(
        title: String? = nil,
        drawingData: Data? = nil,
        dateCreated: Date? = nil,
        lastModified: Date? = nil,
        pages: [Page]? = nil,
        noteTemplate: CanvasTemplate? = nil
    ) -> Note {
        var copy = Note(
            title: title ?? self.title,
            drawingData: drawingData ?? self.drawingData
        )
        
        // Preserve the original ID
        copy.id = self.id
        
        // Copy over other properties
        copy.dateCreated = dateCreated ?? self.dateCreated
        copy.lastModified = lastModified ?? self.lastModified  
        copy.pages = pages ?? self.pages
        copy.noteTemplate = noteTemplate ?? self.noteTemplate
        
        return copy
    }
    
    func hasDrawingContent() -> Bool {
        // Check legacy drawing data
        if !drawingData.isEmpty {
            if let drawing = try? PKDrawing(data: drawingData), !drawing.strokes.isEmpty {
                return true
            }
        }
        
        // Check pages
        for page in pages {
            if !page.drawingData.isEmpty {
                if let drawing = try? PKDrawing(data: page.drawingData), !drawing.strokes.isEmpty {
                    return true
                }
            }
        }
        
        return false
    }
}



// Simple helper for PKDrawing conversion
extension PKDrawing {
    func toData() -> Data {
        return self.dataRepresentation()
    }
    
    static func fromData(_ data: Data) -> PKDrawing {
        if data.isEmpty {
            return PKDrawing()
        }
        
        do {
            return try PKDrawing(data: data)
        } catch {
            print("Error decoding PKDrawing: \(error)")
            return PKDrawing()
        }
    }
}
