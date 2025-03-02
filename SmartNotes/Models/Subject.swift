//
//  Subject.swift
//  SmartNotes
//
//  Created on 2/25/25.
//  Updated on 3/7/25 with enhanced features
//
//  This file defines the Subject model used throughout the application.
//  Key properties:
//    - Basic subject metadata (ID, name, creation date)
//    - Notes collection contained within the subject
//    - Color theming for visual organization
//    - Display and sorting preferences
//

import SwiftUI

struct Subject: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var dateCreated: Date = Date()
    var lastModified: Date = Date()
    
    // Container for notes
    var notes: [Note]
    
    // Display properties
    var colorName: String
    
    // Now user can override this if they want
    var iconName: String = "doc.text"
    
    var isArchived: Bool = false
    var isFavorite: Bool = false
    
    // User preferences
    var defaultViewMode: ViewMode = .grid
    var defaultSortOption: SortOption = .dateModified
    var defaultSortOrder: SortOrder = .descending
    
    // Limit for total notes (0 = unlimited)
    var noteLimit: Int = 0
    
    // Initialize with name, notes, color, and optional icon
    // If icon is omitted, we fall back to the suggested default
    init(name: String,
         notes: [Note],
         colorName: String,
         iconName: String? = nil)
    {
        self.name = name
        self.notes = notes
        self.colorName = colorName
        
        // If the caller provided a custom icon, use it;
        // otherwise, default to a suggestion based on the name
        if let iconName = iconName {
            self.iconName = iconName
        } else {
            self.iconName = Self.suggestIconForName(name)
        }
    }
    
    // MARK: - Enum Declarations
    
    enum ViewMode: String, Codable {
        case grid = "Grid"
        case list = "List"
        case compact = "Compact"
    }
    
    enum SortOption: String, Codable {
        case title = "Title"
        case dateCreated = "Date Created"
        case dateModified = "Date Modified"
        case pageCount = "Page Count"
    }
    
    enum SortOrder: String, Codable {
        case ascending = "Ascending"
        case descending = "Descending"
    }
    
    // MARK: - Hashable / Equatable
    
    func hash(into hasher: inout Hasher) {
        // Use the UUID for hashing since it's unique
        hasher.combine(id)
    }
    
    static func == (lhs: Subject, rhs: Subject) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Color
    
    // Convert the color name to SwiftUI's Color
    var color: Color {
        switch colorName.lowercased() {
        case "red":      return .red
        case "orange":   return .orange
        case "yellow":   return .yellow
        case "green":    return .green
        case "blue":     return .blue
        case "purple":   return .purple
        case "pink":     return .pink
        case "indigo":   return .indigo
        case "mint":     return .mint
        case "teal":     return .teal
        case "cyan":     return .cyan
        case "brown":    return .brown
        default:         return .gray
        }
    }
    
    // MARK: - Automatic Icon Suggestion
    
    private static func suggestIconForName(_ name: String) -> String {
        let lowercaseName = name.lowercased()
        
        // Common subject categories
        if lowercaseName.contains("math")       { return "function" }
        if lowercaseName.contains("science")    { return "atom" }
        if lowercaseName.contains("history")    { return "book" }
        if lowercaseName.contains("art")        { return "paintbrush" }
        if lowercaseName.contains("literature")
           || lowercaseName.contains("english") { return "text.book.closed" }
        if lowercaseName.contains("music")      { return "music.note" }
        if lowercaseName.contains("language")   { return "character.bubble" }
        if lowercaseName.contains("project")    { return "folder" }
        if lowercaseName.contains("meeting")    { return "person.3" }
        if lowercaseName.contains("idea")
           || lowercaseName.contains("brain")   { return "lightbulb" }
        if lowercaseName.contains("todo")
           || lowercaseName.contains("task")    { return "checklist" }
        
        // Default
        return "doc.text"
    }
    
    // MARK: - Timestamps
    
    mutating func touch() {
        self.lastModified = Date()
    }
    
    // MARK: - Stats
    
    func getStats() -> SubjectStats {
        let totalNotes = notes.count
        let emptyNotes = notes.filter { !$0.hasDrawingContent() }.count
        let totalPages = notes.reduce(0) { $0 + $1.pages.count }
        let averagePagesPerNote = totalNotes > 0
            ? Double(totalPages) / Double(totalNotes)
            : 0
        
        return SubjectStats(
            totalNotes: totalNotes,
            emptyNotes: emptyNotes,
            totalPages: totalPages,
            averagePagesPerNote: averagePagesPerNote,
            lastModified: self.lastModified
        )
    }
}

// MARK: - SubjectStats

struct SubjectStats {
    let totalNotes: Int
    let emptyNotes: Int
    let totalPages: Int
    let averagePagesPerNote: Double
    let lastModified: Date
}
