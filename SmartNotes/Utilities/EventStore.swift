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
    private var middleware: [String: Middleware<AppState>] = [:]
    
    /// Save middleware reference for direct access
    private var saveMiddleware: SaveMiddleware?
    
    /// Event bus for publishing state changes
    private let eventBus = EventBus.shared
    
    /// Initializes a new store with the given initial state
    /// - Parameter initialState: The initial state of the application
    init(initialState: AppState = AppState()) {
        self.state = initialState
        setupDefaultMiddleware()
    }
    
    /// Register middleware to be run before the reducers
    /// - Parameters:
    ///   - middleware: The middleware function to register
    ///   - name: A unique name for the middleware for logging and management
    func register(middleware: @escaping Middleware<AppState>, name: String) {
        self.middleware[name] = middleware
        print("📄 Registered middleware: \(name)")
    }
    
    /// Set up the default middleware for logging and persistence
    private func setupDefaultMiddleware() {
        // Register the logging middleware
        register(middleware: { state, action in
            print("📄 Action: \(action.description)")
        }, name: "LoggingMiddleware")
    }
    
    /// Force an immediate save of the current state
    func forceSave() {
        saveMiddleware?.forceSave(state: state)
    }
    
    /// Dispatch an action to the store
    /// - Parameter action: The action to dispatch
    func dispatch(_ action: Action) {
        // Run middleware before state changes
        for (_, mw) in middleware {
            mw(state, action)
        }
        
        // Create a new state by applying reducers
        let newState = reduce(state: state, action: action)
        
        // Update the published state with the new state
        self.state = newState
        
        // Publish an event for the action if needed
        publishEventForAction(action)
    }
    
    /// Publish appropriate events for certain actions
    /// - Parameter action: The action that was dispatched
    private func publishEventForAction(_ action: Action) {
        switch action {
        case let pageAction as PageAction:
            switch pageAction {
            case .selectPage(let pageIndex, _):
                eventBus.publish(PageEvents.PageSelected(pageIndex: pageIndex))
                
            case .addPage(let page, _, _):
                eventBus.publish(PageEvents.PageAdded(pageId: page.id))
                
            case .reorderPages(let fromIndex, let toIndex, _, _):
                eventBus.publish(PageEvents.PageReordering(fromIndex: fromIndex, toIndex: toIndex))
                
            default:
                break
            }
            
        case let templateAction as TemplateAction:
            switch templateAction {
            case .setPageTemplate(let template, _, _, _), .setNoteTemplate(let template, _, _):
                eventBus.publish(TemplateEvents.TemplateChanged(template: template))
                
            case .setDefaultTemplate(let template):
                eventBus.publish(TemplateEvents.TemplateChanged(template: template))
                
            case .addUserTemplate, .removeUserTemplate, .addRecentTemplate:
                // These actions don't need to publish events
                break
            }
            
        case let navigationAction as NavigationAction:
            switch navigationAction {
            case .updateSubjectSidebarVisibility(let isVisible):
                eventBus.publish(UIEvents.SidebarVisibilityChanged(isVisible: isVisible))
                
            default:
                break
            }
            
        case let settingsAction as SettingsAction:
            switch settingsAction {
            case .updateDebugModeSetting(let isEnabled):
                eventBus.publish(SystemEvents.DebugModeChanged(isEnabled: isEnabled))
                
            case .updateAutoScrollSetting(let isEnabled):
                eventBus.publish(SystemEvents.AutoScrollSettingChanged(isEnabled: isEnabled))
                
            default:
                break
            }
            
        default:
            break
        }
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
            
        case let action as DrawingToolAction:
            newState.uiState.drawingToolState = drawingToolReducer(state: state.uiState.drawingToolState, action: action)
            
        case let action as ExportAction:
            newState.uiState.exportState = exportReducer(state: state.uiState.exportState, action: action)
            
        case let action as SystemAction:
            newState.metaState = systemReducer(state: state.metaState, action: action)
            
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
            
        case .reorderSubjects(let fromIndex, let toIndex):
            // Make sure indices are valid
            if fromIndex != toIndex &&
               fromIndex >= 0 && fromIndex < newState.subjects.count &&
               toIndex >= 0 && toIndex < newState.subjects.count {
                
                // Remember the subject being moved
                let subject = newState.subjects[fromIndex]
                
                // Remove it from the old position
                newState.subjects.remove(at: fromIndex)
                
                // Insert it at the new position
                newState.subjects.insert(subject, at: toIndex)
                
                // Update the selected subject index if needed
                if let selectedIndex = newState.selection.selectedSubjectIndex {
                    if selectedIndex == fromIndex {
                        newState.selection.selectedSubjectIndex = toIndex
                    } else if selectedIndex > fromIndex && selectedIndex <= toIndex {
                        newState.selection.selectedSubjectIndex = selectedIndex - 1
                    } else if selectedIndex < fromIndex && selectedIndex >= toIndex {
                        newState.selection.selectedSubjectIndex = selectedIndex + 1
                    }
                }
            }
            
        case .importSubject(let subject):
            // Add the imported subject to the list
            newState.subjects.append(subject)
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
            
        case .reorderNotes(let fromIndex, let toIndex, let subjectID):
            // Find the subject and reorder the notes
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if fromIndex != toIndex &&
                   fromIndex >= 0 && fromIndex < newState.subjects[subjectIndex].notes.count &&
                   toIndex >= 0 && toIndex < newState.subjects[subjectIndex].notes.count {
                    
                    // Remember the note being moved
                    let note = newState.subjects[subjectIndex].notes[fromIndex]
                    
                    // Remove it from the old position
                    newState.subjects[subjectIndex].notes.remove(at: fromIndex)
                    
                    // Insert it at the new position
                    newState.subjects[subjectIndex].notes.insert(note, at: toIndex)
                    
                    // Update the selected note index if needed
                    if newState.selection.selectedSubjectID == subjectID,
                       let selectedNoteIndex = newState.selection.selectedNoteIndex {
                        if selectedNoteIndex == fromIndex {
                            newState.selection.selectedNoteIndex = toIndex
                        } else if selectedNoteIndex > fromIndex && selectedNoteIndex <= toIndex {
                            newState.selection.selectedNoteIndex = selectedNoteIndex - 1
                        } else if selectedNoteIndex < fromIndex && selectedNoteIndex >= toIndex {
                            newState.selection.selectedNoteIndex = selectedNoteIndex + 1
                        }
                    }
                    
                    newState.subjects[subjectIndex].touch()
                }
            }
            
        case .moveNote(let noteID, let fromSubjectID, let toSubjectID):
            // Find the source and destination subjects
            if let fromSubjectIndex = newState.subjects.firstIndex(where: { $0.id == fromSubjectID }),
               let toSubjectIndex = newState.subjects.firstIndex(where: { $0.id == toSubjectID }),
               let noteIndex = newState.subjects[fromSubjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                
                // Get the note to move
                let note = newState.subjects[fromSubjectIndex].notes[noteIndex]
                
                // Remove from source subject
                newState.subjects[fromSubjectIndex].notes.remove(at: noteIndex)
                newState.subjects[fromSubjectIndex].touch()
                
                // Add to destination subject
                newState.subjects[toSubjectIndex].notes.append(note)
                newState.subjects[toSubjectIndex].touch()
                
                // Update selection if needed
                if newState.selection.selectedNoteID == noteID {
                    // Update subject selection
                    newState.selection.selectedSubjectID = toSubjectID
                    newState.selection.selectedSubjectIndex = toSubjectIndex
                    
                    // Update note selection
                    newState.selection.selectedNoteIndex = newState.subjects[toSubjectIndex].notes.count - 1
                }
            }
            
        case .duplicateNote(let noteID, let subjectID):
            // Find the subject and note
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }),
               let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                
                // Get the original note
                let originalNote = newState.subjects[subjectIndex].notes[noteIndex]
                
                // Create a new note with a fresh UUID
                let noteCopy = Note(
                    id: UUID(),  // New UUID for the copy
                    title: originalNote.title + " (Copy)",
                    drawingData: originalNote.drawingData,
                    dateCreated: Date(),
                    lastModified: Date(),
                    pages: [],
                    noteTemplate: originalNote.noteTemplate
                )
                
                // Create new pages with new IDs
                var newPages: [Page] = []
                for page in originalNote.pages {
                    let newPage = Page(
                        id: UUID(),  // New UUID for each page
                        drawingData: page.drawingData,
                        template: page.template,
                        pageNumber: page.pageNumber,
                        isBookmarked: page.isBookmarked
                    )
                    newPages.append(newPage)
                }
                
                // Add pages to the copy
                var noteWithPages = noteCopy
                noteWithPages.pages = newPages
                
                // Add the copy to the subject
                newState.subjects[subjectIndex].notes.append(noteWithPages)
                newState.subjects[subjectIndex].touch()
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
            
        case .updateDrawingData(let pageID, let drawingData, let noteID, let subjectID):
            // Find the subject, note, and page, then update its drawing data
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    if let pageIndex = newState.subjects[subjectIndex].notes[noteIndex].pages.firstIndex(where: { $0.id == pageID }) {
                        newState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex].drawingData = drawingData
                        newState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                        newState.subjects[subjectIndex].touch()
                    }
                }
            }
            
        case .duplicatePage(let pageID, let noteID, let subjectID):
            // Find the subject, note, and page
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    if let pageIndex = newState.subjects[subjectIndex].notes[noteIndex].pages.firstIndex(where: { $0.id == pageID }) {
                        // Get the original page
                        let originalPage = newState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex]
                        
                        // Create a new page with a fresh UUID
                        let pageCopy = Page(
                            id: UUID(),  // New UUID for the copy
                            drawingData: originalPage.drawingData,
                            template: originalPage.template,
                            pageNumber: originalPage.pageNumber,
                            isBookmarked: originalPage.isBookmarked
                        )
                        
                        // Insert the copy after the original
                        newState.subjects[subjectIndex].notes[noteIndex].pages.insert(pageCopy, at: pageIndex + 1)
                        
                        // Update page numbers
                        for (index, _) in newState.subjects[subjectIndex].notes[noteIndex].pages.enumerated() {
                            newState.subjects[subjectIndex].notes[noteIndex].pages[index].pageNumber = index + 1
                        }
                        
                        newState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                        newState.subjects[subjectIndex].touch()
                    }
                }
            }
            
        case .clearPage(let pageID, let noteID, let subjectID):
            // Find the subject, note, and page, then clear its content
            if let subjectIndex = newState.subjects.firstIndex(where: { $0.id == subjectID }) {
                if let noteIndex = newState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
                    if let pageIndex = newState.subjects[subjectIndex].notes[noteIndex].pages.firstIndex(where: { $0.id == pageID }) {
                        // Clear the drawing data but keep the template
                        let template = newState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex].template
                        let pageNumber = newState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex].pageNumber
                        
                        let emptyPage = Page(
                            id: pageID,
                            drawingData: Data(),
                            template: template,
                            pageNumber: pageNumber
                        )
                        
                        newState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex] = emptyPage
                        newState.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
                        newState.subjects[subjectIndex].touch()
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
            
        case .addUserTemplate(let template, let name):
            // Add the template to the user templates collection
            newState.contentState.templates.userTemplates[name] = template
            
        case .removeUserTemplate(let name):
            // Remove the template from the user templates collection
            newState.contentState.templates.userTemplates.removeValue(forKey: name)
            
        case .addRecentTemplate(let template):
            // Add the template to the recent templates list
            // Remove it first if it already exists to avoid duplicates
            newState.contentState.templates.recentTemplates.removeAll(where: { $0 == template })
            
            // Add it to the beginning of the list
            newState.contentState.templates.recentTemplates.insert(template, at: 0)
            
            // Limit the list to the last 10 templates
            if newState.contentState.templates.recentTemplates.count > 10 {
                newState.contentState.templates.recentTemplates.removeLast()
            }
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
            
        case .openSettings, .closeSettings:
            // These actions are handled by the app's navigation system
            break
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
            
        case .setDefaultTemplate(let template):
            newState.defaultTemplate = template
            
        case .setDefaultViewMode(let viewMode):
            newState.defaultViewMode = viewMode
            
        case .setDefaultSortOption(let sortOption):
            newState.defaultSortOption = sortOption
            
        case .setDefaultSortOrder(let sortOrder):
            newState.defaultSortOrder = sortOrder
            
        case .setShowPageThumbnails(let isVisible):
            newState.showPageThumbnails = isVisible
            
        case .setAutoSaveInterval(let intervalSeconds):
            newState.autoSaveIntervalSeconds = intervalSeconds
            
        case .setShowTemplateGridLines(let isVisible):
            newState.showTemplateGridLines = isVisible
            
        case .resetToDefaults:
            // Reset all settings to their default values
            newState = SettingsState()
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
    
    /// Reducer for drawing tool actions
    /// - Parameters:
    ///   - state: The current drawing tool state
    ///   - action: The drawing tool action to apply
    /// - Returns: The new drawing tool state
    private func drawingToolReducer(state: DrawingToolState, action: DrawingToolAction) -> DrawingToolState {
        var newState = state
        
        switch action {
        case .selectTool(let tool):
            newState.selectedTool = tool
            // If selecting a drawing tool, disable eraser mode
            if case .eraser = tool.type {} else {
                newState.isEraserActive = false
            }
            
        case .selectColor(let color):
            newState.selectedColor = color
            
        case .setLineWidth(let width):
            newState.lineWidth = width
            
        case .toggleEraser(let isActive):
            newState.isEraserActive = isActive
            if isActive {
                // Store the current tool so we can switch back
                // When eraser is active, tool remains the same but we use eraser behavior
            }
            
        case .toggleToolPalette(let isExpanded):
            newState.isToolPaletteExpanded = isExpanded
        }
        
        return newState
    }
    
    /// Reducer for export actions
    /// - Parameters:
    ///   - state: The current export state
    ///   - action: The export action to apply
    /// - Returns: The new export state
    private func exportReducer(state: ExportState, action: ExportAction) -> ExportState {
        var newState = state
        
        switch action {
        case .setExportFormat(let format):
            newState.exportFormat = format
            
        case .updateExportSettings(let includeSubjectName, let includeNoteTitle, let includeDate):
            newState.includeSubjectName = includeSubjectName
            newState.includeNoteTitle = includeNoteTitle
            newState.includeDate = includeDate
            
        case .exportNote, .exportSubject:
            // These actions don't change state, they trigger side effects
            // which should be handled by middleware
            break
        }
        
        return newState
    }
    
    /// Reducer for system actions
    /// - Parameters:
    ///   - state: The current meta state
    ///   - action: The system action to apply
    /// - Returns: The new meta state
    private func systemReducer(state: MetaState, action: SystemAction) -> MetaState {
        var newState = state
        
        switch action {
        case .appWillEnterBackground:
            newState.isInForeground = false
            
        case .appWillEnterForeground:
            newState.isInForeground = true
            
        case .updateSyncStatus(let status):
            newState.syncStatus = status
            if case .notSyncing = status {
                newState.lastSyncTime = Date()
            }
            
        case .updateMemoryUsage(let bytes):
            newState.performanceMetrics.memoryUsageBytes = bytes
            
        case .updatePerformanceMetrics(let metrics):
            newState.performanceMetrics = metrics
            
        case .recordError(let message, let isCritical):
            newState.errorState.errorCount += 1
            newState.errorState.latestErrorMessage = message
            newState.errorState.latestErrorTime = Date()
            newState.errorState.hasCriticalError = isCritical
            
        case .clearCriticalError:
            newState.errorState.hasCriticalError = false
        }
        
        return newState
    }
}

// MARK: - Convenience Methods

extension EventStore {
    /// Method to load data from SaveMiddleware
    func loadInitialState() {
        print("📥 EventStore: Loading initial state from SaveMiddleware")
        
        // Create SaveMiddleware instance
        let saveMiddleware = SaveMiddleware()
        
        // Register the save middleware
        register(middleware: saveMiddleware.middleware, name: "SaveMiddleware")
        self.saveMiddleware = saveMiddleware
        
        // Load data from SaveMiddleware
        if let savedData = saveMiddleware.loadSavedData() {
            // Create a new state with the loaded subjects
            var newState = AppState()
            newState.contentState.subjects = savedData.subjects
            
            // Set default selections if available
            if !newState.contentState.subjects.isEmpty {
                newState.contentState.selection.selectedSubjectID = newState.contentState.subjects[0].id
                newState.contentState.selection.selectedSubjectIndex = 0
            }
            
            // Set the loaded settings
            newState.settingsState = savedData.settings
            
            // Update the store's state
            self.state = newState
            
            print("📥 EventStore: Loaded \(savedData.subjects.count) subjects from SaveMiddleware")
        } else {
            print("📥 EventStore: No saved data found, using default state")
        }
    }
    
    /// Load saved settings from UserDefaults
    private func loadSettingsFromUserDefaults(newState: inout AppState) {
        let defaults = UserDefaults.standard
        
        // Load finger drawing setting
        if defaults.object(forKey: "disableFingerDrawing") != nil {
            newState.settingsState.disableFingerDrawing = defaults.bool(forKey: "disableFingerDrawing")
        }
        
        // Load auto-scroll setting
        if defaults.object(forKey: "autoScrollEnabled") != nil {
            newState.settingsState.autoScrollEnabled = defaults.bool(forKey: "autoScrollEnabled")
        }
        
        // Load default template setting (would need more complex logic to decode CanvasTemplate)
        // ... add template loading logic here ...
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
