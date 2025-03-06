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
}

/// State related to the content of the application (subjects, notes, pages)
struct ContentState: Equatable {
    /// All subjects in the application
    var subjects: [Subject] = []
    
    /// Currently selected subject, note, and page indices
    var selection: SelectionState = SelectionState()
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
} 