# EventStore Architecture Guide

## Overview

SmartNotes has been migrated from a direct mutation/notification-based architecture to a unidirectional data flow architecture centered around the EventStore pattern. This architectural shift provides numerous benefits:

1. **Predictable State Changes**: All state mutations flow through a single pipeline
2. **Improved Testability**: Pure reducer functions are easy to test
3. **Centralized Error Handling**: Middleware can catch and handle errors
4. **Time-Travel Debugging**: Action history can be recorded and replayed
5. **Event-Based Communication**: Components can subscribe to specific event types
6. **Performance Optimization**: Can batch and optimize state updates

## Core Concepts

### State

The entire application state is represented by a single immutable state tree in `AppState`. The state is divided into logical sections:

- **ContentState**: Subjects, notes, pages, and their contents
- **UIState**: UI-specific state like navigation, selections, and preferences
- **SettingsState**: Application settings and configurations

```swift
struct AppState {
    var contentState: ContentState
    var uiState: UIState
    var settingsState: SettingsState
}
```

### Actions

State can only be changed by dispatching actions. Actions are plain structs that describe what happened. SmartNotes defines action types for each domain:

- **SubjectAction**: For subject-related operations
- **NoteAction**: For note-related operations
- **PageAction**: For page-related operations
- **NavigationAction**: For navigation operations
- **TemplateAction**: For template operations
- **DrawingToolAction**: For drawing tool operations
- **SystemAction**: For system-level events (app lifecycle, etc.)

Example action:
```swift
struct NoteAction {
    struct addNote: Action {
        let note: Note
        let subjectID: UUID
    }
    // ...other note actions
}
```

### Reducers

Reducers are pure functions that take the current state and an action, and return a new state. They are responsible for handling specific domains:

```swift
func noteReducer(state: inout ContentState, action: Action) -> Void {
    switch action {
    case let action as NoteAction.addNote:
        // Add the note to the state
        if let subjectIndex = state.subjects.firstIndex(where: { $0.id == action.subjectID }) {
            var subject = state.subjects[subjectIndex]
            subject.notes.append(action.note)
            state.subjects[subjectIndex] = subject
        }
    // Handle other note actions...
    default:
        break // Ignore actions this reducer doesn't handle
    }
}
```

### EventStore

The central state container that maintains the app state, dispatches actions, and applies reducers:

```swift
class EventStore: ObservableObject {
    @Published private(set) var state: AppState
    private var middlewares: [Middleware]
    private var reducers: [Reducer]
    let events = PassthroughSubject<Action, Never>()
    
    func dispatch(_ action: Action) {
        // Apply middlewares, reducers, and publish events
    }
}
```

### EventBus

A communication bus for publishing and subscribing to events:

```swift
class EventBus {
    static let shared = EventBus()
    
    func publish<E: Event>(_ event: E) {
        // Publish an event
    }
    
    func subscribe<E: Event>(_ eventType: E.Type, handler: @escaping (E) -> Void) -> AnyCancellable {
        // Subscribe to events of a specific type
    }
}
```

## Using EventStore in Views

### Reading State

Access state directly from the EventStore:

```swift
struct MyView: View {
    @EnvironmentObject var eventStore: EventStore
    
    var body: some View {
        List(eventStore.state.contentState.subjects) { subject in
            Text(subject.name)
        }
    }
}
```

### Updating State

Dispatch actions to modify state:

```swift
Button("Add Subject") {
    let newSubject = Subject(name: "New Subject")
    eventStore.dispatch(SubjectAction.addSubject(newSubject))
}
```

### Listening for Events

Subscribe to specific events:

```swift
// Setup subscription manager
private let subscriptionManager = SubscriptionManager()

// Subscribe in onAppear
.onAppear {
    subscriptionManager.subscribe(NoteEvents.NoteCreated.self) { event in
        // Handle the event
    }
}

// Clean up in onDisappear
.onDisappear {
    subscriptionManager.clearAll()
}
```

Or use the convenient ViewModifier:

```swift
.onEvent(PageAction.self) { action in
    if case let PageAction.selectPage(pageIndex, _) = action {
        selectedPageIndex = pageIndex
    }
}
```

## Middleware

Middleware intercepts actions before they reach the reducers, allowing for side effects, async operations, and more:

```swift
func myMiddleware() -> Middleware {
    return { state, action, next in
        // Do something before the reducer
        print("Action dispatched: \(action)")
        
        // Call the next middleware in chain
        next(action)
        
        // Do something after the reducer
        if action is ErrorAction {
            // Handle error
        }
    }
}
```

Register middleware with the EventStore:

```swift
eventStore.register(middleware: myMiddleware(), name: "LoggingMiddleware")
```

## Best Practices

1. **Keep reducers pure**: They should not have side effects or modify external state
2. **Design actions for clarity**: Action names should describe what happened
3. **Keep middleware focused**: Each middleware should have a single responsibility
4. **Use computed properties**: For derived state that doesn't need to be stored
5. **Favor small, composable components**: Makes the UI easier to maintain
6. **Use event subscriptions for cross-component communication**: Avoids tight coupling
7. **Clean up subscriptions**: Always clear subscriptions in `onDisappear`
8. **Test reducers thoroughly**: They contain the core business logic

## Migration Path

While migration is mostly complete, a few components still use the legacy DataManager for persistence. The save/load operations will be fully migrated in a future update. When creating new components, always use the EventStore architecture.

## Debugging

1. **Action Tracing**: Set `GlobalSettings.debugModeEnabled = true` to see action dispatches in the console
2. **State Inspection**: Use the Debug Menu to inspect the current state tree
3. **EventBus Monitoring**: Enable verbose event logging with `EventBus.shared.verboseLogging = true`

## Further Reading

- [Redux Documentation](https://redux.js.org/introduction/core-concepts) - Many concepts in EventStore are inspired by Redux
- [The Elm Architecture](https://guide.elm-lang.org/architecture/) - Another inspiration for unidirectional data flow
- [Combine Framework Documentation](https://developer.apple.com/documentation/combine) - Used for reactive programming in EventStore 