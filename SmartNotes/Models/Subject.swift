//
//  Subject.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  This file defines the Subject data model, which represents a category
//  for organizing notes. Each subject has:
//    - A unique ID
//    - A name (like "Math" or "History")
//    - An array of notes that belong to this subject
//    - A color name (stored as a string) and a computed color property
//    - A last modified timestamp
//
//  The file also implements Hashable and Equatable for use in SwiftUI lists
//  and provides a "touch()" method to update the last modified date.
//

import SwiftUI
import PencilKit

struct Subject: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var notes: [Note]
    var colorName: String
    var lastModified: Date = Date()  // Add last modified date for tracking changes
    
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
        default:         return .gray
        }
    }
    
    // Implement Hashable manually - simplified to just compare IDs
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Simplified equality check that only compares IDs
    static func == (lhs: Subject, rhs: Subject) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Helper method to touch the subject, marking it as modified
    mutating func touch() {
        self.lastModified = Date()
    }
}
