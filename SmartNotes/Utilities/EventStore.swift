// 
//  EventStore.swift
//  SmartNotes
//
//  Created on 6/12/25.
//
//  This file defines the EventStore, which is the central hub for
//  state management in the application. It follows the Redux pattern:
//  - The store holds the current application state
//  - State can only be changed by dispatching actions
//  - Reducers handle the actions and produce new state
//  - Subscribers are notified of state changes
//

import Foundation
import SwiftUI
import Combine

/// Middleware typealias for intercepting actions
typealias Middleware<StoreState> = (StoreState, Action) -> Void

/// The EventStore is the central manager for the application's state
class EventStore: ObservableObject {
    /// The current application state - readonly for outside classes
    @Published private(set) var state: AppState
    
    /// Middleware to be applied before reducers
    private var middleware: [Middleware<AppState>] = []
    
    /// Initializes a new store with the given initial state
    /// - Parameter initialState: The initial state of the application
    init(initialState: AppState = AppState()) {
        self.state = initialState
        setupDefaultMiddleware()
    }
    
    /// Register middleware to be run before the reducers
    /// - Parameter middleware: The middleware to register
    func register(middleware: @escaping Middleware<AppState>) {
        self.middleware.append(middleware)
    }
    
    /// Set up the default middleware for logging and persistence
    private func setupDefaultMiddleware() {
        // Register the logging middleware
        register { state, action in
            print("📄 Action: \(action.description)")
        }
    }
    
    /// Dispatch an action to the store
    /// - Parameter action: The action to dispatch
    func dispatch(_ action: Action) {
        // Run middleware before state changes
        for mw in middleware {
            mw(state, action)
        }
        
        // Create a new state by applying reducers
        let newState = reduce(state: state, action: action)
        
        // Update the published state with the new state
        self.state = newState
    }
    
    /// Apply the reducer to the current state and action to produce a new state
    /// - Parameters:
    ///   - state: The current state
    ///   - action: The action to apply
    /// - Returns: The new state
    private func reduce(state: AppState, action: Action) -> AppState {
        // First, create a copy of the current state
        var newState = state
        
        // Apply specific reducers based on the action type
        switch action {
        case let action as SubjectAction:
            newState.contentState = subjectReducer(state: state.contentState, action: action)
            
        case let action as NoteAction:
            newState.contentState = noteReducer(state: state.contentState, action: action)
            
        case let action as PageAction:
            newState.contentState = pageReducer(state: state.contentState, action: action)
            
        case let action as TemplateAction:
            newState = templateReducer(state: state, action: action)
            
        case let action as NavigationAction:
            newState.uiState = navigationReducer(state: state.uiState, action: action)
            
        case let action as SettingsAction:
            newState.settingsState = settingsReducer(state: state.settingsState, action: action)
            newState.uiState = settingsUIReducer(state: state.uiState, action: action)
            
        default:
            // Unknown action type, return unchanged state
            break
        }
        
        return newState
    }
    
    // MARK: - Individual Reducers
    
    /// Reducer for subject-related actions
    /// - Parameters:
    ///   - state: The current content state
    ///   - action: The subject action to apply
    /// - Returns: The new content state
    private func subjectReducer(state: ContentState, action: SubjectAction) -> ContentState {
        var newState = state
        
        switch action {
        case .addSubject(let subject):
            // Add the subject to the list
            newState.subjects.append(subject)
            
            // Automatically select the new subject if none is selected
            if newState.selection.selectedSubjectID == nil {
                newState.selection.selectedSubjectID = subject.id
                newState.selection.selectedSubjectIndex = newState.subjects.count - 1
            }
            
        case .updateSubject(let subject):
            // Find and update the subject
            if let index = newState.subjects.firstIndex(where: { $0.id == subject.id }) {
                newState.subjects[index] = subject
            }
            
        case .deleteSubject(let id):
            // Find and remove the subject
            if let index = newState.subjects.firstIndex(where: { $0.id == id }) {
                newState.subjects.remove(at: index)
                
                // If the deleted subject was selected, clear the selection
                if newState.selection.selectedSubjectID == id {
                    newState.selection.selectedSubjectID = nil
                    newState.selection.selectedSubjectIndex = nil
                    newState.selection.selectedNoteID = nil
                    newState.selection.selectedNoteIndex = nil
                    newState.selection.selectedPageID = nil
                    newState.selection.selectedPageIndex = 0
                }
                
                // If there are other subjects, select the first one
                if !newState.subjects.isEmpty {
                    newState.selection.selectedSubjectID = newState.subjects[0].id
                    newState.selection.selectedSubjectIndex = 0
                }
            }
            
        case .selectSubject(let id):
            if let id = id {
                // Find and select the subject
                if let index = newState.subjects.firstIndex(where: { $0.id == id }) {
                    newState.selection.selectedSubjectID = id
                    newState.selection.selectedSubjectIndex = index
                    
                    // Reset note and page selection
                    newState.selection.selectedNoteID = nil
                    newState.selection.selectedNoteIndex = nil
                    newState.selection.selectedPageID = nil
                    newState.selection.selectedPageIndex = 0
                }
            } else {
                // Clear the selection
                newState.selection.selectedSubjectID = nil
                newState.selection.selectedSubjectIndex = nil
                newState.selection.selectedNoteID = nil
                newState.selection.selectedNoteIndex = nil
                newState.selection.selectedPageID = nil
                newState.selection.selectedPageIndex = 0
            }
        }
        
        return newState
    }
    
    /// Reducer for note-related actions
    /// - Parameters:
    ///   - state: The current content state
    ///   - action: The note action to apply
    /// - Returns: The new content state
    private func noteReducer(state: ContentState, action: NoteAction) -> ContentState {
        var newState = state
        
        switch action {
        case .addNote(let note, let subjectID):
            // Find the subject and add the note
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                newState.subjects[subjectIndex].notes.append(note)
                newState.subjects[subjectIndex].touch()
                
                // Automatically select the new note
                let noteIndex = newState.subjects[subjectIndex].notes.count - 1
                newState.selection.selectedNoteID = note.id
                newState.selection.selectedNoteIndex = noteIndex
                newState.selection.selectedPageIndex = 0
                if !note.pages.isEmpty {
                    newState.selection.selectedPageID = note.pages[0].id
                }
            }
            
        case .updateNote(let note, let subjectID):
            // Find the subject and update the note
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == note.id }) {
                    newState.subjects[subjectIndex].notes[noteIndex] = note
                    newState.subjects[subjectIndex].touch()
                }
            }
            
        case .deleteNote(let noteID, let subjectID):
            // Find the subject and delete the note
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    newState.subjects[subjectIndex].notes.remove(at: noteIndex)
                    newState.subjects[subjectIndex].touch()
                    
                    // If the deleted note was selected, clear the selection
                    if newState.selection.selectedNoteID == noteID {
                        newState.selection.selectedNoteID = nil
                        newState.selection.selectedNoteIndex = nil
                        newState.selection.selectedPageID = nil
                        newState.selection.selectedPageIndex = 0
                    }
                }
            }
            
        case .selectNote(let noteID, let subjectID):
            if let noteID = noteID, let subjectID = subjectID {
                // Find the subject and note, then select it
                if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                    newState.selection.selectedSubjectID = subjectID
                    newState.selection.selectedSubjectIndex = subjectIndex
                    
                    if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                        newState.selection.selectedNoteID = noteID
                        newState.selection.selectedNoteIndex = noteIndex
                        newState.selection.selectedPageIndex = 0
                        
                        // Select the first page if available
                        if !newState.subjects[subjectIndex].notes[noteIndex].pages.isEmpty {
                            newState.selection.selectedPageID = newState.subjects[subjectIndex].notes[noteIndex].pages[0].id
                        } else {
                            newState.selection.selectedPageID = nil
                        }
                    }
                }
            } else {
                // Clear note selection but keep subject selection
                newState.selection.selectedNoteID = nil
                newState.selection.selectedNoteIndex = nil
                newState.selection.selectedPageID = nil
                newState.selection.selectedPageIndex = 0
            }
        }
        
        return newState
    }
    
    /// Reducer for page-related actions
    /// - Parameters:
    ///   - state: The current content state
    ///   - action: The page action to apply
    /// - Returns: The new content state
    private func pageReducer(state: ContentState, action: PageAction) -> ContentState {
        var newState = state
        
        switch action {
        case .addPage(let page, let noteID, let subjectID):
            // Find the subject and note, then add the page
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    newState.subjects[subjectIndex].notes[noteIndex].pages.append(page)
                    newState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                    newState.subjects[subjectIndex].touch()
                    
                    // Select the new page if the parent note is selected
                    if newState.selection.selectedNoteID == noteID {
                        let pageIndex = newState.subjects[subjectIndex].notes[noteIndex].pages.count - 1
                        newState.selection.selectedPageIndex = pageIndex
                        newState.selection.selectedPageID = page.id
                    }
                }
            }
            
        case .updatePage(let page, let noteID, let subjectID):
            // Find the subject, note, and page, then update it
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    if let pageIndex = newState.subjects[subjectIndex].notes[noteIndex].pages.firstIndex(where: { $0.id == page.id }) {
                        newState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex] = page
                        newState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                        newState.subjects[subjectIndex].touch()
                    }
                }
            }
            
        case .deletePage(let pageID, let noteID, let subjectID):
            // Find the subject, note, and page, then delete it
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    if let pageIndex = newState.subjects[subjectIndex].notes[noteIndex].pages.firstIndex(where: { $0.id == pageID }) {
                        // Don't delete the last page, just clear it
                        if newState.subjects[subjectIndex].notes[noteIndex].pages.count <= 1 {
                            let emptyPage = Page(
                                id: pageID,
                                drawingData: Data(),
                                template: newState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex].template,
                                pageNumber: 1
                            )
                            newState.subjects[subjectIndex].notes[noteIndex].pages[0] = emptyPage
                        } else {
                            newState.subjects[subjectIndex].notes[noteIndex].pages.remove(at: pageIndex)
                            
                            // Update page numbers
                            for (index, _) in newState.subjects[subjectIndex].notes[noteIndex].pages.enumerated() {
                                newState.subjects[subjectIndex].notes[noteIndex].pages[index].pageNumber = index + 1
                            }
                            
                            // Adjust the selected page index if necessary
                            if newState.selection.selectedNoteID == noteID {
                                if newState.selection.selectedPageIndex >= pageIndex {
                                    let newPageIndex = max(0, min(newState.selection.selectedPageIndex - 1, newState.subjects[subjectIndex].notes[noteIndex].pages.count - 1))
                                    newState.selection.selectedPageIndex = newPageIndex
                                    newState.selection.selectedPageID = newState.subjects[subjectIndex].notes[noteIndex].pages[newPageIndex].id
                                }
                            }
                        }
                        
                        newState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                        newState.subjects[subjectIndex].touch()
                    }
                }
            }
            
        case .reorderPages(let fromIndex, let toIndex, let noteID, let subjectID):
            // Find the subject and note, then reorder the pages
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    if fromIndex != toIndex &&
                       fromIndex >= 0 && fromIndex < newState.subjects[subjectIndex].notes[noteIndex].pages.count &&
                       toIndex >= 0 && toIndex < newState.subjects[subjectIndex].notes[noteIndex].pages.count {
                        
                        // Remember the page being moved
                        let page = newState.subjects[subjectIndex].notes[noteIndex].pages[fromIndex]
                        
                        // Remove it from the old position
                        newState.subjects[subjectIndex].notes[noteIndex].pages.remove(at: fromIndex)
                        
                        // Insert it at the new position
                        newState.subjects[subjectIndex].notes[noteIndex].pages.insert(page, at: toIndex)
                        
                        // Update page numbers
                        for (index, _) in newState.subjects[subjectIndex].notes[noteIndex].pages.enumerated() {
                            newState.subjects[subjectIndex].notes[noteIndex].pages[index].pageNumber = index + 1
                        }
                        
                        // If the note is selected and the page being moved is selected, update the selection
                        if newState.selection.selectedNoteID == noteID && newState.selection.selectedPageIndex == fromIndex {
                            newState.selection.selectedPageIndex = toIndex
                        }
                        
                        newState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                        newState.subjects[subjectIndex].touch()
                    }
                }
            }
            
        case .selectPage(let pageIndex, let pageID):
            // Find the selected subject and note
            if let subjectIndex = newState.selection.selectedSubjectIndex,
               let noteIndex = newState.selection.selectedNoteIndex {
                
                // Make sure the indices are valid
                if subjectIndex >= 0 && subjectIndex < newState.subjects.count &&
                   noteIndex >= 0 && noteIndex < newState.subjects[subjectIndex].notes.count &&
                   pageIndex >= 0 && pageIndex < newState.subjects[subjectIndex].notes[noteIndex].pages.count {
                    
                    newState.selection.selectedPageIndex = pageIndex
                    
                    // Update the page ID if provided, otherwise get it from the pages array
                    if let pageID = pageID {
                        newState.selection.selectedPageID = pageID
                    } else {
                        newState.selection.selectedPageID = newState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex].id
                    }
                }
            }
        }
        
        return newState
    }
    
    /// Reducer for template-related actions
    /// - Parameters:
    ///   - state: The current app state
    ///   - action: The template action to apply
    /// - Returns: The new app state
    private func templateReducer(state: AppState, action: TemplateAction) -> AppState {
        var newState = state
        
        switch action {
        case .setNoteTemplate(let template, let noteID, let subjectID):
            // Find the subject and note, then set the template
            if let subjectIndex = newState.contentState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.contentState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    newState.contentState.subjects[subjectIndex].notes[noteIndex].noteTemplate = template
                    newState.contentState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                    newState.contentState.subjects[subjectIndex].touch()
                }
            }
            
        case .setPageTemplate(let template, let pageID, let noteID, let subjectID):
            // Find the subject, note, and page, then set the template
            if let subjectIndex = newState.contentState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.contentState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    if let pageIndex = newState.contentState.subjects[subjectIndex].notes[noteIndex].pages.firstIndex(where: { $0.id == pageID }) {
                        newState.contentState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex].template = template
                        newState.contentState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                        newState.contentState.subjects[subjectIndex].touch()
                    }
                }
            }
            
        case .setDefaultTemplate(let template):
            // Set the default template for new notes
            newState.settingsState.defaultTemplate = template
        }
        
        return newState
    }
    
    /// Reducer for navigation-related actions
    /// - Parameters:
    ///   - state: The current UI state
    ///   - action: The navigation action to apply
    /// - Returns: The new UI state
    private func navigationReducer(state: UIState, action: NavigationAction) -> UIState {
        var newState = state
        
        switch action {
        case .navigateToSubjectsList:
            newState.navigationState = .subjectsList
            
        case .navigateToNote(let noteIndex, let subjectID):
            newState.navigationState = .noteDetail(noteIndex: noteIndex, subjectID: subjectID)
            
        case .updatePageNavigatorVisibility(let isVisible):
            newState.isPageNavigatorVisible = isVisible
            
        case .updateSubjectSidebarVisibility(let isVisible):
            newState.isSubjectSidebarVisible = isVisible
            
        case .updatePageSelectionActive(let isActive):
            newState.isPageSelectionActive = isActive
        }
        
        return newState
    }
    
    /// Reducer for settings-related actions
    /// - Parameters:
    ///   - state: The current settings state
    ///   - action: The settings action to apply
    /// - Returns: The new settings state
    private func settingsReducer(state: SettingsState, action: SettingsAction) -> SettingsState {
        var newState = state
        
        switch action {
        case .updateFingerDrawingSetting(let isDisabled):
            newState.disableFingerDrawing = isDisabled
            
        case .updateAutoScrollSetting(let isEnabled):
            newState.autoScrollEnabled = isEnabled
            
        case .updateDebugModeSetting:
            // Debug mode is handled in settingsUIReducer, not here
            break
            
        case .updateSearchText:
            // This doesn't affect settings state, only UI state
            break
        }
        
        return newState
    }
    
    /// Reducer for settings actions that affect UI state
    /// - Parameters:
    ///   - state: The current UI state
    ///   - action: The settings action to apply
    /// - Returns: The new UI state
    private func settingsUIReducer(state: UIState, action: SettingsAction) -> UIState {
        var newState = state
        
        switch action {
        case .updateDebugModeSetting(let isEnabled):
            newState.isDebugMode = isEnabled
            
        case .updateSearchText(let text):
            newState.searchText = text
            
        default:
            // Other settings don't affect UI state
            break
        }
        
        return newState
    }
}

// MARK: - Convenience Methods

extension EventStore {
    /// Method to load data from DataManager
    func loadFromDataManager(_ dataManager: DataManager) {
        // Create a new state with the loaded subjects
        var newState = AppState()
        newState.contentState.subjects = dataManager.subjects
        
        // Set default selections if available
        if !newState.contentState.subjects.isEmpty {
            newState.contentState.selection.selectedSubjectID = newState.contentState.subjects[0].id
            newState.contentState.selection.selectedSubjectIndex = 0
        }
        
        // Update the store's state
        self.state = newState
    }
    
    /// Method to save data to DataManager
    func saveToDataManager(_ dataManager: DataManager) {
        // Update the DataManager's subjects with the store's state
        dataManager.subjects = state.contentState.subjects
        
        // Schedule a save operation
        dataManager.saveData()
    }
    
    /// Create a new note with default settings
    func createNewNote(title: String) {
        // Make sure a subject is selected
        guard let subjectID = state.contentState.selection.selectedSubjectID else {
            return
        }
        
        // Create a new page with the default template
        let newPage = Page(
            drawingData: Data(),
            template: state.settingsState.defaultTemplate,
            pageNumber: 1
        )
        
        // Create a new note
        let newNote = Note(
            title: title,
            drawingData: Data(),
            pages: [newPage],
            noteTemplate: state.settingsState.defaultTemplate
        )
        
        // Dispatch an action to add the note
        dispatch(NoteAction.addNote(newNote, subjectID: subjectID))
    }
} 