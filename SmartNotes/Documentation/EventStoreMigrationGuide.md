# SmartNotes EventStore Migration Guide

This document provides guidance for migrating SmartNotes to a unified EventStore architecture, eliminating the mixed state management approach.

## Table of Contents

1. [Overview](#overview)
2. [Architecture Principles](#architecture-principles)
3. [Migration Steps](#migration-steps)
4. [Component Migration Guide](#component-migration-guide)
5. [Testing and Validation](#testing-and-validation)
6. [Troubleshooting](#troubleshooting)

## Overview

SmartNotes is transitioning from a mixed state management approach (using DataManager, NotificationCenter, and direct state manipulation) to a unified EventStore architecture based on the Redux pattern:

- **Single Source of Truth**: All application state is stored in a central `AppState` object
- **Immutable State**: State is never directly modified, only through actions and reducers
- **Unidirectional Data Flow**: Actions → Reducers → State → UI
- **Middleware for Side Effects**: Persistence, logging, error handling, etc.

## Architecture Principles

### Core Components

1. **AppState**: The complete application state model
   - ContentState: Subjects, notes, pages, and selection state
   - UIState: Navigation, visibility, tools, and UI preferences
   - SettingsState: User preferences and application settings
   - MetaState: System information, performance metrics, and error state

2. **Actions**: Events that describe state changes
   - SubjectAction: Add, update, delete, select subjects
   - NoteAction: Add, update, delete, select notes
   - PageAction: Add, update, delete, reorder, select pages
   - TemplateAction: Set templates for notes, pages, and defaults
   - NavigationAction: Control navigation and UI visibility
   - SettingsAction: Update user preferences
   - DrawingToolAction: Control drawing tools and settings
   - ExportAction: Control export settings and operations
   - SystemAction: Handle system events and state

3. **Reducers**: Pure functions that produce new state based on actions
   - Each reducer handles a specific domain (subjects, notes, pages, etc.)
   - Reducers never modify existing state, only create new state
   - No side effects in reducers (no API calls, no persistence, etc.)

4. **Middleware**: Handle side effects
   - SaveMiddleware: Persist state changes to storage
   - LoggingMiddleware: Log actions and state changes
   - PerformanceMiddleware: Track and optimize performance
   - ErrorHandlingMiddleware: Centralized error management

5. **EventBus**: Type-safe event publishing and subscription
   - Decouples components that need to react to state changes
   - Replaces NotificationCenter for inter-component communication

### Data Flow

1. UI triggers an action via `eventStore.dispatch(action)`
2. Middleware processes the action (logging, performance tracking, etc.)
3. Reducers create a new state based on the action
4. EventStore updates its state and notifies subscribers
5. UI updates based on the new state

## Migration Steps

### 1. Preparation

- [x] Enhance AppState to include all application state
- [x] Define comprehensive actions for all state changes
- [x] Implement complete reducers for all domains
- [x] Create middleware for side effects
- [x] Set up EventBus for type-safe event publishing

### 2. Component Migration

For each component:

1. Identify direct DataManager usage and replace with EventStore actions
2. Replace NotificationCenter observers with EventBus subscribers
3. Update UI to read from EventStore state instead of local state
4. Test the component thoroughly before moving to the next

### 3. DataManager Deprecation

1. Move all persistence logic to SaveMiddleware
2. Update DataManager to use EventStore internally
3. Gradually remove direct DataManager access from components
4. Eventually remove DataManager entirely

## Component Migration Guide

### View Components

```swift
// BEFORE
class NoteView: UIView {
    private var note: Note
    private let dataManager: DataManager
    
    init(note: Note, dataManager: DataManager) {
        self.note = note
        self.dataManager = dataManager
        super.init(frame: .zero)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTemplateChanged),
            name: NSNotification.Name("TemplateChanged"),
            object: nil
        )
    }
    
    func updateNote() {
        // Direct state modification
        note.lastModified = Date()
        dataManager.updateNote(in: note.subjectID, note: note)
    }
    
    @objc func handleTemplateChanged(_ notification: Notification) {
        // Handle template change
    }
}

// AFTER
class NoteView: UIView {
    @EnvironmentObject private var eventStore: EventStore
    private var subscriptions = Set<AnyCancellable>()
    
    private var noteID: UUID
    private var subjectID: UUID
    
    init(noteID: UUID, subjectID: UUID) {
        self.noteID = noteID
        self.subjectID = subjectID
        super.init(frame: .zero)
        
        // Subscribe to events
        EventBus.shared.subscribe(TemplateEvents.TemplateChanged.self) { [weak self] event in
            self?.handleTemplateChanged(event.template)
        }.store(in: &subscriptions)
    }
    
    private var note: Note? {
        // Read from central state
        guard let subjectIndex = eventStore.state.contentState.subjects.firstIndex(where: { $0.id == subjectID }),
              let noteIndex = eventStore.state.contentState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) else {
            return nil
        }
        return eventStore.state.contentState.subjects[subjectIndex].notes[noteIndex]
    }
    
    func updateNote() {
        // Create a copy with modifications
        guard var updatedNote = note else { return }
        updatedNote.lastModified = Date()
        
        // Dispatch action to update state
        eventStore.dispatch(NoteAction.updateNote(updatedNote, subjectID: subjectID))
    }
    
    func handleTemplateChanged(_ template: CanvasTemplate) {
        // Handle template change
    }
}
```

### Manager Components

```swift
// BEFORE
class CanvasManager {
    private let dataManager: DataManager
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    func saveDrawing(_ drawing: PKDrawing, for pageID: UUID, in noteID: UUID, subjectID: UUID) {
        guard let subjectIndex = dataManager.subjects.firstIndex(where: { $0.id == subjectID }),
              let noteIndex = dataManager.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }),
              let pageIndex = dataManager.subjects[subjectIndex].notes[noteIndex].pages.firstIndex(where: { $0.id == pageID }) else {
            return
        }
        
        let drawingData = drawing.dataRepresentation()
        dataManager.subjects[subjectIndex].notes[noteIndex].pages[pageIndex].drawingData = drawingData
        dataManager.subjects[subjectIndex].notes[noteIndex].lastModified = Date()
        dataManager.scheduleSave()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("PageDrawingChanged"),
            object: pageID
        )
    }
}

// AFTER
class CanvasManager {
    private let eventStore: EventStore
    
    init(eventStore: EventStore) {
        self.eventStore = eventStore
    }
    
    func saveDrawing(_ drawing: PKDrawing, for pageID: UUID, in noteID: UUID, subjectID: UUID) {
        let drawingData = drawing.dataRepresentation()
        
        // Find the page to update
        guard let subjectIndex = eventStore.state.contentState.subjects.firstIndex(where: { $0.id == subjectID }),
              let noteIndex = eventStore.state.contentState.subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }),
              let pageIndex = eventStore.state.contentState.subjects[subjectIndex].notes[noteIndex].pages.firstIndex(where: { $0.id == pageID }) else {
            return
        }
        
        // Create a copy of the page with the new drawing data
        var updatedPage = eventStore.state.contentState.subjects[subjectIndex].notes[noteIndex].pages[pageIndex]
        updatedPage.drawingData = drawingData
        
        // Dispatch action to update state
        eventStore.dispatch(PageAction.updatePage(updatedPage, noteID: noteID, subjectID: subjectID))
        
        // Publish event for components that need to react to drawing changes
        EventBus.shared.publish(DrawingEvents.PageDrawingChanged(pageId: pageID))
    }
}
```

## Testing and Validation

For each migrated component:

1. **Functional Testing**: Ensure the component behaves identically before and after migration
2. **State Inspection**: Verify that state changes are correctly reflected in the EventStore
3. **Action Logging**: Check that appropriate actions are dispatched for all state changes
4. **Performance Testing**: Measure and compare performance before and after migration
5. **Error Handling**: Test error scenarios to ensure proper error handling

## Troubleshooting

### Common Issues

1. **State Not Updating**: Ensure actions are being dispatched and reducers are handling them correctly
2. **Missing Events**: Check that events are being published and subscribed to correctly
3. **Performance Issues**: Use PerformanceMiddleware to identify slow actions and optimize them
4. **Memory Leaks**: Check for strong reference cycles in event subscriptions

### Debugging Tools

1. **Action Logging**: Enable LoggingMiddleware to see all actions being dispatched
2. **State Inspection**: Add a debug view to inspect the current state
3. **Performance Metrics**: Use PerformanceMiddleware to track action processing time
4. **Error Tracking**: Use ErrorHandlingMiddleware to track and report errors
