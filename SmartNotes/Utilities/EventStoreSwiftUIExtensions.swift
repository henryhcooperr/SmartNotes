import SwiftUI
import Combine

// MARK: - SwiftUI Extensions for EventStore Integration

// Extension to provide action dispatching via a view modifier
extension View {
    /// Dispatches an action to the EventStore when a condition is true
    /// - Parameters:
    ///   - action: The action to dispatch
    ///   - value: The binding value to observe
    ///   - transform: Transform function to create an action from the value
    /// - Returns: The modified view
    func dispatchOnChange<Value: Equatable, Action: SmartNotes.Action>(
        _ value: Binding<Value>,
        transform: @escaping (Value) -> Action
    ) -> some View {
        self.onChange(of: value.wrappedValue) { _, newValue in
            let action = transform(newValue)
            DispatchQueue.main.async {
                withAnimation {
                    // Access the EventStore from the environment
                    if let eventStore = (try? findEventStore()) {
                        eventStore.dispatch(action)
                    }
                }
            }
        }
    }
    
    /// Helper function to find the EventStore in the environment
    private func findEventStore() throws -> EventStore? {
        // In a real app, you would access the environment differently
        // This is a placeholder that should be replaced with the correct approach
        return nil
    }
}

// MARK: - Create Selectors from EventStore State

extension EventStore {
    /// Creates a selector binding that maps a part of the state to a binding
    /// - Parameter keyPath: The keyPath to the value in the state
    /// - Returns: A binding to the selected value
    func select<Value>(_ keyPath: KeyPath<AppState, Value>) -> Binding<Value> {
        Binding<Value>(
            get: { self.state[keyPath: keyPath] },
            set: { _ in }  // Read-only binding
        )
    }
    
    /// Creates a mutable selector binding that dispatches actions when modified
    /// - Parameters:
    ///   - keyPath: The keyPath to the value in the state
    ///   - actionProvider: A function that takes the new value and returns an action
    /// - Returns: A binding that dispatches actions when modified
    func selectMutable<Value, A: Action>(
        _ keyPath: KeyPath<AppState, Value>,
        actionProvider: @escaping (Value) -> A
    ) -> Binding<Value> {
        Binding<Value>(
            get: { self.state[keyPath: keyPath] },
            set: { newValue in
                let action = actionProvider(newValue)
                self.dispatch(action)
            }
        )
    }
}

// MARK: - Convenience Selectors

extension EventStore {
    /// Get a binding to the current navigation state
    var navigationBinding: Binding<NavigationState> {
        selectMutable(\.uiState.navigationState) { newState in
            switch newState {
            case .subjectsList:
                return NavigationAction.navigateToSubjectsList
            case .noteDetail(let noteIndex, let subjectID):
                return NavigationAction.navigateToNote(
                    noteIndex: noteIndex, 
                    subjectID: subjectID
                )
            }
        }
    }
    
    /// Get a binding to the search text
    var searchTextBinding: Binding<String> {
        selectMutable(\.uiState.searchText) { newText in
            SettingsAction.updateSearchText(text: newText)
        }
    }
    
    /// Get a binding to debug mode
    var debugModeBinding: Binding<Bool> {
        selectMutable(\.uiState.isDebugMode) { isEnabled in
            SettingsAction.updateDebugModeSetting(isEnabled: isEnabled)
        }
    }
} 