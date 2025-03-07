// 
//  Action.swift
//  SmartNotes
//
//  DEPRECATED: This file has been replaced by use cases and repositories in the DDD architecture.
//  Please use the appropriate use case classes in Core/Application/UseCases instead.
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
    
    /// Reorder subjects
    case reorderSubjects(fromIndex: Int, toIndex: Int)
    
    /// Import subject from external source
    case importSubject(Subject)
    
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
        case .reorderSubjects(let fromIndex, let toIndex):
            return "Reorder subjects from index \(fromIndex) to \(toIndex)"
        case .importSubject(let subject):
            return "Import subject: \(subject.name)"
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
    
    /// Reorder notes within a subject
    case reorderNotes(fromIndex: Int, toIndex: Int, subjectID: UUID)
    
    /// Move a note to a different subject
    case moveNote(noteID: UUID, fromSubjectID: UUID, toSubjectID: UUID)
    
    /// Duplicate a note
    case duplicateNote(noteID: UUID, subjectID: UUID)
    
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
        case .reorderNotes(let fromIndex, let toIndex, let subjectID):
            return "Reorder notes from index \(fromIndex) to \(toIndex) in subject: \(subjectID)"
        case .moveNote(let noteID, let fromSubjectID, let toSubjectID):
            return "Move note: \(noteID) from subject: \(fromSubjectID) to subject: \(toSubjectID)"
        case .duplicateNote(let noteID, let subjectID):
            return "Duplicate note: \(noteID) in subject: \(subjectID)"
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
    
    /// Update the drawing data for a page
    case updateDrawingData(pageID: UUID, drawingData: Data, noteID: UUID, subjectID: UUID)
    
    /// Duplicate a page
    case duplicatePage(pageID: UUID, noteID: UUID, subjectID: UUID)
    
    /// Clear a page's content
    case clearPage(pageID: UUID, noteID: UUID, subjectID: UUID)
    
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
        case .updateDrawingData(let pageID, _, let noteID, let subjectID):
            return "Update drawing data for page: \(pageID) in note: \(noteID) in subject: \(subjectID)"
        case .duplicatePage(let pageID, let noteID, let subjectID):
            return "Duplicate page: \(pageID) in note: \(noteID) in subject: \(subjectID)"
        case .clearPage(let pageID, let noteID, let subjectID):
            return "Clear page: \(pageID) in note: \(noteID) in subject: \(subjectID)"
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
    
    /// Add a custom template
    case addUserTemplate(template: CanvasTemplate, name: String)
    
    /// Remove a custom template
    case removeUserTemplate(name: String)
    
    /// Add a template to recent templates
    case addRecentTemplate(template: CanvasTemplate)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .setNoteTemplate(let template, let noteID, let subjectID):
            return "Set note template to: \(template.type.rawValue) for note: \(noteID) in subject: \(subjectID)"
        case .setPageTemplate(let template, let pageID, let noteID, let subjectID):
            return "Set page template to: \(template.type.rawValue) for page: \(pageID) in note: \(noteID) in subject: \(subjectID)"
        case .setDefaultTemplate(let template):
            return "Set default template to: \(template.type.rawValue)"
        case .addUserTemplate(let template, let name):
            return "Add user template: \(name) with type: \(template.type.rawValue)"
        case .removeUserTemplate(let name):
            return "Remove user template: \(name)"
        case .addRecentTemplate(let template):
            return "Add recent template: \(template.type.rawValue)"
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
    
    /// Open the settings screen
    case openSettings
    
    /// Close the settings screen
    case closeSettings
    
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
        case .openSettings:
            return "Open settings screen"
        case .closeSettings:
            return "Close settings screen"
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
    
    /// Update default template
    case setDefaultTemplate(template: CanvasTemplate)
    
    /// Update default view mode
    case setDefaultViewMode(viewMode: Subject.ViewMode)
    
    /// Update default sort option
    case setDefaultSortOption(sortOption: Subject.SortOption)
    
    /// Update default sort order
    case setDefaultSortOrder(sortOrder: Subject.SortOrder)
    
    /// Update page thumbnails visibility
    case setShowPageThumbnails(isVisible: Bool)
    
    /// Update auto-save interval
    case setAutoSaveInterval(intervalSeconds: TimeInterval)
    
    /// Update template grid lines visibility
    case setShowTemplateGridLines(isVisible: Bool)
    
    /// Reset all settings to defaults
    case resetToDefaults
    
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
        case .setDefaultTemplate(let template):
            return "Set default template to: \(template.type.rawValue)"
        case .setDefaultViewMode(let viewMode):
            return "Set default view mode to: \(viewMode)"
        case .setDefaultSortOption(let sortOption):
            return "Set default sort option to: \(sortOption)"
        case .setDefaultSortOrder(let sortOrder):
            return "Set default sort order to: \(sortOrder)"
        case .setShowPageThumbnails(let isVisible):
            return "Set show page thumbnails to: \(isVisible)"
        case .setAutoSaveInterval(let intervalSeconds):
            return "Set auto-save interval to: \(intervalSeconds) seconds"
        case .setShowTemplateGridLines(let isVisible):
            return "Set show template grid lines to: \(isVisible)"
        case .resetToDefaults:
            return "Reset all settings to defaults"
        }
    }
}

// MARK: - Drawing Tool Actions

/// Actions related to drawing tools
enum DrawingToolAction: Action {
    /// Change the selected drawing tool
    case selectTool(tool: DrawingTool)
    
    /// Change the selected color
    case selectColor(color: Color)
    
    /// Change the line width
    case setLineWidth(width: CGFloat)
    
    /// Toggle the eraser
    case toggleEraser(isActive: Bool)
    
    /// Toggle the tool palette expanded state
    case toggleToolPalette(isExpanded: Bool)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .selectTool(let tool):
            return "Select drawing tool: \(tool.type.rawValue)"
        case .selectColor(let color):
            return "Select color: \(color)"
        case .setLineWidth(let width):
            return "Set line width to: \(width)"
        case .toggleEraser(let isActive):
            return "Toggle eraser to: \(isActive)"
        case .toggleToolPalette(let isExpanded):
            return "Toggle tool palette expanded to: \(isExpanded)"
        }
    }
}

// MARK: - Export Actions

/// Actions related to export
enum ExportAction: Action {
    /// Set export format
    case setExportFormat(format: ExportFormat)
    
    /// Update export settings
    case updateExportSettings(includeSubjectName: Bool, includeNoteTitle: Bool, includeDate: Bool)
    
    /// Initiate export for a note
    case exportNote(noteID: UUID, subjectID: UUID)
    
    /// Initiate export for all notes in a subject
    case exportSubject(subjectID: UUID)
    
    /// A text description of the action
    var description: String {
        switch self {
        case .setExportFormat(let format):
            return "Set export format to: \(format.rawValue)"
        case .updateExportSettings(let includeSubjectName, let includeNoteTitle, let includeDate):
            return "Update export settings: includeSubjectName=\(includeSubjectName), includeNoteTitle=\(includeNoteTitle), includeDate=\(includeDate)"
        case .exportNote(let noteID, let subjectID):
            return "Export note: \(noteID) in subject: \(subjectID)"
        case .exportSubject(let subjectID):
            return "Export all notes in subject: \(subjectID)"
        }
    }
}

// MARK: - System Actions

/// Actions related to system operations
enum SystemAction: Action {
    /// Update application state when going to background
    case appWillEnterBackground
    
    /// Update application state when returning to foreground
    case appWillEnterForeground
    
    /// Update sync status
    case updateSyncStatus(status: SyncStatus)
    
    /// Update memory usage information
    case updateMemoryUsage(bytes: UInt64)
    
    /// Update performance metrics
    case updatePerformanceMetrics(metrics: PerformanceMetrics)
    
    /// Record an error
    case recordError(message: String, isCritical: Bool)
    
    /// Acknowledge and clear critical error
    case clearCriticalError
    
    /// A text description of the action
    var description: String {
        switch self {
        case .appWillEnterBackground:
            return "App will enter background"
        case .appWillEnterForeground:
            return "App will enter foreground"
        case .updateSyncStatus(let status):
            switch status {
            case .notSyncing:
                return "Update sync status to: not syncing"
            case .syncing:
                return "Update sync status to: syncing"
            case .error(let message):
                return "Update sync status to error: \(message)"
            }
        case .updateMemoryUsage(let bytes):
            return "Update memory usage to: \(bytes) bytes"
        case .updatePerformanceMetrics:
            return "Update performance metrics"
        case .recordError(let message, let isCritical):
            return "Record error: \(message), critical: \(isCritical)"
        case .clearCriticalError:
            return "Clear critical error"
        }
    }
} 