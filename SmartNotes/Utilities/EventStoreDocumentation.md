# EventStore Documentation for SmartNotes

## Overview

The EventStore is a Redux-inspired state management system for the SmartNotes application. It provides a centralized way to manage application state and handle state changes through a unidirectional data flow pattern.

## Key Concepts

- **Single Source of Truth**: The EventStore maintains a single source of truth for the entire application state.
- **Immutable State**: State is never directly modified - only through dispatched actions.
- **Unidirectional Data Flow**: State changes follow a one-way flow from actions → reducers → state → UI.
- **Actions**: Plain objects that describe what happened in the app.
- **Reducers**: Pure functions that determine how state changes in response to actions.
- **Middleware**: Intercepts actions before they reach the reducers for side effects.

## Core Components

### AppState

The `AppState` is the root state object that contains all application state, structured into logical domains:

```swift
struct AppState: Equatable {
    var contentState: ContentState
    var uiState: UIState
    var settingsState: SettingsState
}
```

### Actions

Actions are defined as Swift enums that implement the `Action` protocol:

```swift
protocol Action {
    var description: String { get }
}

enum SubjectAction: Action { /* ... */ }
enum NoteAction: Action { /* ... */ }
// ...
```

### EventStore

The central class that manages state and processes actions:

```swift
class EventStore: ObservableObject {
    @Published var state: AppState
    
    func dispatch(_ action: Action) {
        // Process the action
    }
}
```

## How to Use the EventStore

### Access the EventStore in Views

The EventStore is made available throughout the app via SwiftUI's environment:

```swift
struct MyView: View {
    @EnvironmentObject var eventStore: EventStore
    
    // ...
}
```

### Reading State

Access state from the EventStore:

```swift
let subjects = eventStore.state.contentState.subjects
let searchText = eventStore.state.uiState.searchText
```

### Dispatching Actions

To modify state, dispatch actions:

```swift
// Add a new subject
eventStore.dispatch(SubjectAction.addSubject(
    name: "Math",
    colorName: "blue",
    iconName: "book.closed"
))

// Update a note
eventStore.dispatch(NoteAction.updateNote(
    updatedNote,
    subjectID: subject.id
))

// Navigate to a note
eventStore.dispatch(NavigationAction.navigateToNote(
    noteIndex: 3,
    subjectID: UUID()
))
```

### Using Selectors

The EventStore provides convenient selector methods to create bindings:

```swift
// Read-only binding
let navigationState = eventStore.select(\.uiState.navigationState)

// Mutable binding that automatically dispatches actions
let searchText = eventStore.searchTextBinding
```

## Best Practices

1. **Never modify state directly** - always use actions.
2. **Keep actions small and focused** - each action should represent one specific change.
3. **Reducers must be pure functions** - no side effects allowed.
4. **Use middleware for side effects** - like API calls, persistence, etc.
5. **Consider state shape carefully** - organize by domain and access patterns.

## Migration Guidelines

When migrating from direct state management to the EventStore:

1. Replace `@State` and `@Binding` with computed properties or selectors.
2. Replace direct state updates with dispatched actions.
3. Use the `copyWith` pattern to create new state objects.
4. Extract side effects to middleware.

## Example: Converting a View

### Before:

```swift
struct SubjectView: View {
    @Binding var subject: Subject
    
    func addNote() {
        subject.notes.append(Note(title: "New Note"))
    }
}
```

### After:

```swift
struct SubjectView: View {
    @EnvironmentObject var eventStore: EventStore
    let subjectID: UUID
    
    var subject: Subject? {
        eventStore.state.contentState.subjects.first { $0.id == subjectID }
    }
    
    func addNote() {
        let newNote = Note(
            title: "New Note",
            drawingData: PKDrawing().dataRepresentation()
        )
        eventStore.dispatch(NoteAction.addNote(
            newNote,
            subjectID: subjectID
        ))
    }
}
```

## Debugging

The EventStore includes logging middleware that prints all dispatched actions to the console. Enable debug mode to see additional information:

```swift
eventStore.dispatch(SettingsAction.updateDebugModeSetting(isEnabled: true))
``` 