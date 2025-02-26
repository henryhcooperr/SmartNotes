//
//  Subject.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI
import PencilKit

struct Subject: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var notes: [Note]
    var colorName: String
    
    // Derived property: convert colorName to an actual SwiftUI Color
    var color: Color {
        switch colorName.lowercased() {
        case "red":      return .red
        case "orange":   return .orange
        case "yellow":   return .yellow
        case "green":    return .green
        case "blue":     return .blue
        case "purple":   return .purple
        case "pink":     return .pink
        // Add more custom colors as you like
        default:         return .gray
        }
    }
    
    // Implement Hashable manually
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Subject, rhs: Subject) -> Bool {
        return lhs.id == rhs.id
    }
    
    mutating func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            print("Note updated: \(note.title)")
        }
    }
}
