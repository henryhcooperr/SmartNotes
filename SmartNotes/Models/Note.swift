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
    
    // Implement Hashable manually because Data may not conform to Hashable properly
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id
    }
}

// Helper to convert PKDrawing <-> Data
extension PKDrawing {
    func toData() -> Data {
        return self.dataRepresentation()
    }
    
    static func fromData(_ data: Data) -> PKDrawing {
        do {
            return try PKDrawing(data: data)
        } catch {
            print("Error decoding PKDrawing: \(error)")
            return PKDrawing()
        }
    }
}
