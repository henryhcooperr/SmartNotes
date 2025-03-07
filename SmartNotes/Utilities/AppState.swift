//
//  AppState.swift
//  SmartNotes
//
//  Created on 6/12/25.
//
//  This file defines the AppState, which is the single source of truth
//  for the application's state. The state is immutable, and all changes
//  must be made through actions dispatched to the EventStore.
//

import Foundation
import SwiftUI
import PencilKit

/// The complete application state model
struct AppState: Equatable {
    /// Content-related state
    var contentState: ContentState = ContentState()
    
    /// UI-related state
    var uiState: UIState = UIState()
    
    /// User preferences and settings
    var settingsState: SettingsState = SettingsState()
    
    /// Application metadata and system state
    var metaState: MetaState = MetaState()
}

/// State related to the content of the application (subjects, notes, pages)
struct ContentState: Equatable {
    /// All subjects in the application
    var subjects: [Subject] = []
    
    /// Currently selected subject, note, and page indices
    var selection: SelectionState = SelectionState()
    
    /// Templates available in the application
    var templates: TemplatesState = TemplatesState()
}

/// State related to selections within the application
struct SelectionState: Equatable {
    /// Index of the currently selected subject
    var selectedSubjectIndex: Int? = nil
    
    /// ID of the currently selected subject
    var selectedSubjectID: UUID? = nil
    
    /// Index of the currently selected note
    var selectedNoteIndex: Int? = nil
    
    /// ID of the currently selected note
    var selectedNoteID: UUID? = nil
    
    /// Index of the currently selected page
    var selectedPageIndex: Int = 0
    
    /// ID of the currently selected page
    var selectedPageID: UUID? = nil
}

/// State related to templates in the application
struct TemplatesState: Equatable {
    /// User-defined templates
    var userTemplates: [String: CanvasTemplate] = [:]
    
    /// Recently used templates
    var recentTemplates: [CanvasTemplate] = []
}

/// State related to the UI of the application
struct UIState: Equatable {
    /// Current navigation state
    var navigationState: NavigationState = .subjectsList
    
    /// Whether the page navigator sidebar is visible
    var isPageNavigatorVisible: Bool = false
    
    /// Whether page selection is active
    var isPageSelectionActive: Bool = false
    
    /// Whether the subject sidebar is visible
    var isSubjectSidebarVisible: Bool = true
    
    /// Current search text
    var searchText: String = ""
    
    /// Whether the app is in debug mode
    var isDebugMode: Bool = false
    
    /// Current drawing tool settings
    var drawingToolState: DrawingToolState = DrawingToolState()
    
    /// Export settings
    var exportState: ExportState = ExportState()
}

/// State related to drawing tools
struct DrawingToolState: Equatable {
    /// Currently selected drawing tool
    var selectedTool: DrawingTool = DrawingTool(type: .pen)
    
    /// Currently selected color
    var selectedColor: Color = .black
    
    /// Currently selected line width
    var lineWidth: CGFloat = 1.0
    
    /// Whether eraser is active
    var isEraserActive: Bool = false
    
    /// Whether the tool palette is expanded
    var isToolPaletteExpanded: Bool = false
}

/// State related to export operations
struct ExportState: Equatable {
    /// Current export format
    var exportFormat: ExportFormat = .pdf
    
    /// Whether to include subject name in exports
    var includeSubjectName: Bool = true
    
    /// Whether to include note title in exports
    var includeNoteTitle: Bool = true
    
    /// Whether to include date in exports
    var includeDate: Bool = true
}

/// Export format options
enum ExportFormat: String, Equatable {
    case pdf
    case image
    case imageSequence
}

/// Represents the possible navigation states in the app
enum NavigationState: Equatable {
    case subjectsList
    case noteDetail(noteIndex: Int, subjectID: UUID)
}

/// State related to user settings and preferences
struct SettingsState: Equatable {
    /// Whether finger drawing is disabled
    var disableFingerDrawing: Bool = false
    
    /// Whether auto-scroll is enabled
    var autoScrollEnabled: Bool = true
    
    /// Current template for new notes
    var defaultTemplate: CanvasTemplate = .none
    
    /// Default view mode for subjects
    var defaultViewMode: Subject.ViewMode = .grid
    
    /// Default sort option for notes
    var defaultSortOption: Subject.SortOption = .dateModified
    
    /// Default sort order for notes
    var defaultSortOrder: Subject.SortOrder = .descending
    
    /// Whether to show page thumbnails
    var showPageThumbnails: Bool = true
    
    /// Auto-save interval in seconds
    var autoSaveIntervalSeconds: TimeInterval = 30
    
    /// Whether to show template grid lines
    var showTemplateGridLines: Bool = true
}

/// Application metadata and system state
struct MetaState: Equatable {
    /// App version
    var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    
    /// Whether the app is in the foreground
    var isInForeground: Bool = true
    
    /// Whether initial data loading has completed
    var isDataLoaded: Bool = false
    
    /// Current sync status
    var syncStatus: SyncStatus = .notSyncing
    
    /// Last sync time
    var lastSyncTime: Date? = nil
    
    /// Performance metrics
    var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    
    /// Error state
    var errorState: ErrorState = ErrorState()
}

/// Performance metrics for the application
struct PerformanceMetrics: Equatable {
    /// Average action processing time in milliseconds
    var averageActionProcessingTimeMs: Double = 0
    
    /// Number of actions processed
    var actionsProcessed: Int = 0
    
    /// Memory usage in bytes
    var memoryUsageBytes: UInt64 = 0
    
    /// Number of template renderings
    var templateRenderings: Int = 0
    
    /// Number of drawing operations
    var drawingOperations: Int = 0
    
    static func == (lhs: PerformanceMetrics, rhs: PerformanceMetrics) -> Bool {
        return lhs.averageActionProcessingTimeMs == rhs.averageActionProcessingTimeMs &&
               lhs.actionsProcessed == rhs.actionsProcessed &&
               lhs.memoryUsageBytes == rhs.memoryUsageBytes &&
               lhs.templateRenderings == rhs.templateRenderings &&
               lhs.drawingOperations == rhs.drawingOperations
    }
}

/// Error state for the application
struct ErrorState: Equatable {
    /// Whether there is a critical error
    var hasCriticalError: Bool = false
    
    /// The most recent error message
    var latestErrorMessage: String? = nil
    
    /// The time of the most recent error
    var latestErrorTime: Date? = nil
    
    /// Number of errors since launch
    var errorCount: Int = 0
    
    static func == (lhs: ErrorState, rhs: ErrorState) -> Bool {
        return lhs.hasCriticalError == rhs.hasCriticalError &&
               lhs.latestErrorMessage == rhs.latestErrorMessage &&
               lhs.latestErrorTime == rhs.latestErrorTime &&
               lhs.errorCount == rhs.errorCount
    }
}

/// Sync status for the application
enum SyncStatus: Equatable {
    case notSyncing
    case syncing
    case error(message: String)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notSyncing, .notSyncing):
            return true
        case (.syncing, .syncing):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
} 
