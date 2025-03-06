# TypedEventBus Documentation

The TypedEventBus is a type-safe event system that replaces the error-prone string-based `NotificationCenter` usage in SmartNotes. This document provides an overview of the system, examples of usage, and migration guidance.

## Overview

The TypedEventBus consists of several key components:

1. **EventBus** - The central hub for event publishing and subscription
2. **Event Protocol** - The protocol that all event types must conform to
3. **Event Types** - Strongly-typed event definitions organized by category
4. **NotificationBridge** - A compatibility layer to support gradual migration
5. **SwiftUI Extensions** - Convenient SwiftUI view modifiers for event subscription

## Benefits Over NotificationCenter

- **Type Safety**: No more string typos or runtime errors from incorrect notification names
- **Self-Documenting**: Each event type clearly communicates its purpose and payload data
- **IDE Support**: Autocomplete suggestions for event types and their properties
- **Centralized Definition**: All events are defined in one place (EventTypes.swift)
- **Memory Safety**: Subscriptions are managed automatically with SwiftUI view lifecycle

## Usage Examples

### Publishing Events

```swift
// Old way (error-prone)
NotificationCenter.default.post(
    name: NSNotification.Name("PageSelected"),
    object: pageIndex
)

// New way (type-safe)
EventBus.shared.publish(PageEvents.PageSelected(pageIndex: pageIndex))
```

### Subscribing to Events in SwiftUI

```swift
// Old way (error-prone)
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PageSelected"))) { notification in
    if let pageIndex = notification.object as? Int {
        // Handle page selection
    }
}

// New way with custom modifier (type-safe)
.onPageSelected { event in
    // Handle page selection with strongly-typed event
    let pageIndex = event.pageIndex
}

// Alternative general approach
.onEvent(PageEvents.PageSelected.self) { event in
    // Handle page selection
}
```

### Subscribing to Events in UIKit/AppKit

```swift
// Old way (error-prone)
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handlePageSelection(_:)),
    name: NSNotification.Name("PageSelected"),
    object: nil
)

// New way (type-safe)
subscriptionManager.subscribe(PageEvents.PageSelected.self) { [weak self] event in
    self?.handlePageSelection(event.pageIndex)
}
```

### Cancelling Subscriptions

```swift
// SwiftUI: Automatically managed through view lifecycle

// UIKit: Clear all subscriptions
subscriptionManager.clearAll()

// Manual: Store and cancel individual subscriptions
let subscription = EventBus.shared.subscribe(PageEvents.PageSelected.self) { event in
    // Handle event
}

// Later...
subscription.cancel()
```

## Available Event Categories

The system defines the following event categories:

1. **PageEvents** - Events related to page navigation and selection
   - PageSelected
   - PageSelectedByUser
   - PageSelectionDeactivated
   - PageAdded
   - PageReordering
   - VisiblePageChanged
   - ScrollToPage

2. **DrawingEvents** - Events related to drawing and canvas interactions
   - PageDrawingChanged
   - LiveDrawingUpdate
   - DrawingStarted
   - DrawingDidComplete

3. **TemplateEvents** - Events related to template management
   - RefreshTemplate
   - ForceTemplateRefresh

4. **UIEvents** - Events related to UI state changes
   - SidebarVisibilityChanged
   - CloseSidebar
   - ToggleSidebar

5. **GridEvents** - Events related to the coordinate grid
   - GridStateChanged
   - ToggleCoordinateGrid

6. **SystemEvents** - Events related to system-wide state changes
   - DebugModeChanged
   - AutoScrollSettingChanged
   - CoordinatorReady

## Creating New Event Types

To add a new event type:

1. Identify the appropriate category in `EventTypes.swift`
2. Define your new event struct within that category
3. Implement the required `Event` protocol properties
4. Add a convenient subscription method to `View` if appropriate

Example:

```swift
// In EventTypes.swift
public enum MyFeatureEvents {
    public struct MyNewEvent: Event {
        public static let description = "Description of what this event represents"
        
        // Event payload properties
        public let someValue: String
        
        public init(someValue: String) {
            self.someValue = someValue
        }
    }
}

// In EventBusSwiftUIExtensions.swift
public extension View {
    func onMyNewEvent(perform action: @escaping (MyFeatureEvents.MyNewEvent) -> Void) -> some View {
        onEvent(MyFeatureEvents.MyNewEvent.self, perform: action)
    }
}
```

## Migration Strategy

The migration from NotificationCenter to TypedEventBus should be done incrementally:

1. **Analyze**: Identify all notification usage in a component
2. **Define**: Ensure all needed event types are defined in `EventTypes.swift`
3. **Migrate Publishers**: Update code that posts notifications to use `EventBus.publish()`
4. **Migrate Subscribers**: Update code that observes notifications to use `EventBus.subscribe()`
5. **Test**: Verify that the migrated component works correctly
6. **Repeat**: Move on to the next component

During migration, the `NotificationBridge` will ensure backward compatibility between legacy and migrated components.

## Best Practices

1. **Event Naming**: Use descriptive names for event types that clearly communicate their purpose
2. **Payload Design**: Include only the necessary data in event payloads, prefer value types
3. **Memory Management**: Use `[weak self]` in closures to prevent retain cycles
4. **Documentation**: Document new event types with descriptive comments
5. **Testing**: Add unit tests for event publishers and subscribers

## Debugging Tools

To help with debugging:

```swift
// List all active event types
let activeEventTypes = EventBus.shared.listActiveEventTypes()
print("Active event types: \(activeEventTypes)")

// Clear subscriptions for a specific event type
EventBus.shared.clearSubscriptions(for: PageEvents.PageSelected.self)

// Clear all subscriptions (use with caution)
EventBus.shared.clearAllSubscriptions()
``` 