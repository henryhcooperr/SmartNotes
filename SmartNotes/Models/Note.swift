//
//  Note.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI
import PencilKit

struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var drawingData: Data
    var dateCreated: Date = Date()
    var lastModified: Date = Date()
    
    // Simplified hash function that only uses ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Simplified equality check
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id
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
