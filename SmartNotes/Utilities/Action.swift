// 
//  Action.swift
//  SmartNotes
//
//  Created on 6/12/25.
//
//  This file defines the Action protocol and basic action types for the EventStore.
//  Actions are the only way to change the application state.
//

import Foundation
import SwiftUI
import PencilKit

/// Protocol that all actions must conform to
protocol Action {
    /// A human-readable description of the action
    var description: String { get }
}

// MARK: - Subject Actions

/// Actions related to subject management
enum SubjectAction: Action {
    /// Add a new subject
    case addSubject(Subject)
    
    /// Update an existing subject
    case updateSubject(Subject)
    
    /// Delete a subject
    case deleteSubject(UUID)
    
    /// Set the selected subject
    case selectSubject(UUID?)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .addSubject(let subject):
            return "Add subject: \(subject.name)"
        case .updateSubject(let subject):
            return "Update subject: \(subject.name)"
        case .deleteSubject(let id):
            return "Delete subject: \(id)"
        case .selectSubject(let id):
            return "Select subject: \(String(describing: id))"
        }
    }
}

// MARK: - Note Actions

/// Actions related to note management
enum NoteAction: Action {
    /// Add a new note to a subject
    case addNote(Note, subjectID: UUID)
    
    /// Update an existing note
    case updateNote(Note, subjectID: UUID)
    
    /// Delete a note
    case deleteNote(noteID: UUID, subjectID: UUID)
    
    /// Set the selected note
    case selectNote(noteID: UUID?, subjectID: UUID?)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .addNote(let note, let subjectID):
            return "Add note: \(note.title.isEmpty ? "Untitled" : note.title) to subject: \(subjectID)"
        case .updateNote(let note, let subjectID):
            return "Update note: \(note.title.isEmpty ? "Untitled" : note.title) in subject: \(subjectID)"
        case .deleteNote(let noteID, let subjectID):
            return "Delete note: \(noteID) from subject: \(subjectID)"
        case .selectNote(let noteID, let subjectID):
            return "Select note: \(String(describing: noteID)) in subject: \(String(describing: subjectID))"
        }
    }
}

// MARK: - Page Actions

/// Actions related to page management
enum PageAction: Action {
    /// Add a new page to a note
    case addPage(Page, noteID: UUID, subjectID: UUID)
    
    /// Update an existing page
    case updatePage(Page, noteID: UUID, subjectID: UUID)
    
    /// Delete a page
    case deletePage(pageID: UUID, noteID: UUID, subjectID: UUID)
    
    /// Reorder pages
    case reorderPages(fromIndex: Int, toIndex: Int, noteID: UUID, subjectID: UUID)
    
    /// Set the selected page
    case selectPage(pageIndex: Int, pageID: UUID?)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .addPage(_, let noteID, let subjectID):
            return "Add page to note: \(noteID) in subject: \(subjectID)"
        case .updatePage(let page, let noteID, let subjectID):
            return "Update page: \(page.id) in note: \(noteID) in subject: \(subjectID)"
        case .deletePage(let pageID, let noteID, let subjectID):
            return "Delete page: \(pageID) from note: \(noteID) in subject: \(subjectID)"
        case .reorderPages(let fromIndex, let toIndex, let noteID, let subjectID):
            return "Reorder pages from index \(fromIndex) to \(toIndex) in note: \(noteID) in subject: \(subjectID)"
        case .selectPage(let pageIndex, let pageID):
            return "Select page at index: \(pageIndex) with ID: \(String(describing: pageID))"
        }
    }
}

// MARK: - Template Actions

/// Actions related to template management
enum TemplateAction: Action {
    /// Set the template for a note
    case setNoteTemplate(template: CanvasTemplate, noteID: UUID, subjectID: UUID)
    
    /// Set the template for a page
    case setPageTemplate(template: CanvasTemplate, pageID: UUID, noteID: UUID, subjectID: UUID)
    
    /// Set the default template for new notes
    case setDefaultTemplate(template: CanvasTemplate)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .setNoteTemplate(let template, let noteID, let subjectID):
            return "Set note template to: \(template.type.rawValue) for note: \(noteID) in subject: \(subjectID)"
        case .setPageTemplate(let template, let pageID, let noteID, let subjectID):
            return "Set page template to: \(template.type.rawValue) for page: \(pageID) in note: \(noteID) in subject: \(subjectID)"
        case .setDefaultTemplate(let template):
            return "Set default template to: \(template.type.rawValue)"
        }
    }
}

// MARK: - Navigation Actions

/// Actions related to navigation
enum NavigationAction: Action {
    /// Navigate to the subjects list
    case navigateToSubjectsList
    
    /// Navigate to a note
    case navigateToNote(noteIndex: Int, subjectID: UUID)
    
    /// Update the page navigator visibility
    case updatePageNavigatorVisibility(isVisible: Bool)
    
    /// Update the subject sidebar visibility
    case updateSubjectSidebarVisibility(isVisible: Bool)
    
    /// Update page selection active state
    case updatePageSelectionActive(isActive: Bool)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .navigateToSubjectsList:
            return "Navigate to subjects list"
        case .navigateToNote(let noteIndex, let subjectID):
            return "Navigate to note at index: \(noteIndex) in subject: \(subjectID)"
        case .updatePageNavigatorVisibility(let isVisible):
            return "Update page navigator visibility to: \(isVisible)"
        case .updateSubjectSidebarVisibility(let isVisible):
            return "Update subject sidebar visibility to: \(isVisible)"
        case .updatePageSelectionActive(let isActive):
            return "Update page selection active to: \(isActive)"
        }
    }
}

// MARK: - Settings Actions

/// Actions related to settings
enum SettingsAction: Action {
    /// Update finger drawing setting
    case updateFingerDrawingSetting(isDisabled: Bool)
    
    /// Update auto-scroll setting
    case updateAutoScrollSetting(isEnabled: Bool)
    
    /// Update debug mode setting
    case updateDebugModeSetting(isEnabled: Bool)
    
    /// Update search text
    case updateSearchText(text: String)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .updateFingerDrawingSetting(let isDisabled):
            return "Update finger drawing setting to disabled: \(isDisabled)"
        case .updateAutoScrollSetting(let isEnabled):
            return "Update auto-scroll setting to enabled: \(isEnabled)"
        case .updateDebugModeSetting(let isEnabled):
            return "Update debug mode setting to enabled: \(isEnabled)"
        case .updateSearchText(let text):
            return "Update search text to: \(text)"
        }
    }
} 