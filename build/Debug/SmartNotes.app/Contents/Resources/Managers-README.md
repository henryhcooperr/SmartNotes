# Canvas Management in SmartNotes

This document describes the centralized canvas management system implemented in the SmartNotes app.

## Overview

The `CanvasManager` class provides a centralized approach to canvas operations throughout the app. It handles:

- Canvas creation and configuration
- Tool management
- Resolution/performance optimization
- Template application
- Drawing state operations (undo/redo)

## Key Components

### CanvasManager

The main management class that handles all canvas-related operations:

```swift
class CanvasManager {
    static let shared = CanvasManager() // Singleton instance
    
    // Canvas creation
    func createCanvas(withID id: UUID? = nil, initialDrawing: Data? = nil) -> PKCanvasView
    
    // Tool management
    func setTool(_ tool: PKInkingTool.InkType, color: UIColor, width: CGFloat)
    
    // Template application
    func applyTemplate(to canvas: PKCanvasView, template: CanvasTemplate, pageSize: CGSize)
    
    // Performance optimization
    func optimizeCanvasForHighResolution(_ canvas: PKCanvasView)
    func adjustQualityForZoom(_ canvas: PKCanvasView, zoomScale: CGFloat)
    func setTemporaryLowResolutionMode(_ canvas: PKCanvasView, enabled: Bool)
}
```

### EventBus

The EventBus system handles communication between components:

```swift
class EventBus {
    static let shared = EventBus() // Singleton instance
    
    // Subscribe to events of a specific type
    func subscribe<T: AnyObject>(_ subscriber: T, eventType: EventType, handler: @escaping (Event) -> Void)
    
    // Unsubscribe from events
    func unsubscribe(_ subscriber: AnyObject)
    
    // Post an event to subscribers
    func post(_ event: Event)
}
```

Events are used for communication instead of NotificationCenter, providing type-safety and better memory management. Key events include:

- `ToolChangedEvent`: When a drawing tool changes
- `ResolutionChangedEvent`: When the resolution scale factor changes

## Canvas ID Management

Canvases are tracked using UUID identifiers, which are associated with the canvas view using object association:

```swift
// Register a canvas with an ID
CanvasManager.shared.registerCanvas(canvasView, withID: uuid)

// Get a canvas by ID
let canvasView = CanvasManager.shared.getCanvas(withID: uuid)
```

## Usage Examples

### Creating a Canvas

```swift
// Create a canvas with a specific ID
let pageID = UUID()
let canvas = CanvasManager.shared.createCanvas(withID: pageID)

// Create a canvas with initial drawing data
let canvas = CanvasManager.shared.createCanvas(withID: page.id, initialDrawing: page.drawingData)
```

### Managing Drawing Tools

```swift
// Set the current tool for all canvases
CanvasManager.shared.setTool(.pen, color: .black, width: 2.0)

// For eraser, use pen with clear color
CanvasManager.shared.setTool(.pen, color: .clear, width: 10.0)
```

### Subscribing to Tool Changes

```swift
// Subscribe to tool change events
EventBus.shared.subscribe(self, eventType: EventType.toolChanged) { event in
    if let toolEvent = event as? ToolChangedEvent {
        // Handle tool change
        updateToolbar(toolEvent.tool, color: toolEvent.color, width: toolEvent.width)
    }
}

// Don't forget to unsubscribe when done
EventBus.shared.unsubscribe(self)
```

### Applying Templates

```swift
// Apply a template to a specific canvas
CanvasManager.shared.applyTemplate(
    to: canvasView,
    template: noteTemplate,
    pageSize: GlobalSettings.scaledPageSize
)

// Apply template to all canvases
CanvasManager.shared.applyTemplateToAllCanvases(
    noteTemplate,
    pageSize: GlobalSettings.scaledPageSize
)
```

### Performance Optimization

```swift
// Optimize for high resolution
CanvasManager.shared.optimizeCanvasForHighResolution(canvasView)

// Adjust quality based on zoom level
CanvasManager.shared.adjustQualityForZoom(canvasView, zoomScale: scrollView.zoomScale)

// Temporarily reduce resolution during interactions
CanvasManager.shared.setTemporaryLowResolutionMode(canvasView, enabled: true)
```

### Drawing State Operations

```swift
// Undo the last operation
CanvasManager.shared.undo(canvasView)

// Redo the last undone operation
CanvasManager.shared.redo(canvasView)

// Clear the canvas
CanvasManager.shared.clearCanvas(canvasView)
```

## Integration with Existing Components

The CanvasManager has been integrated with:

1. **MultiPageUnifiedScrollView** - For canvas creation and layout
2. **CustomToolbar** - For tool management
3. **SinglePageCanvasView** - For individual page canvas management
4. **NoteDetailView** - For note-wide canvas operations

## Benefits

- **Centralized Configuration**: All canvas creation and setup happens in one place
- **Consistent Behavior**: Tools and templates are applied consistently
- **Optimized Performance**: Standard optimization for all canvases
- **Simplified Code**: Views don't need to implement canvas management logic
- **Easier Maintenance**: Canvas-related changes only need to be made in one place
- **Type-Safe Events**: EventBus provides type-safety over NotificationCenter
- **Memory Safety**: Weak references prevent memory leaks when subscribers are deallocated

## Future Improvements

Potential areas for future enhancement:

- Extended tool types and customization
- Advanced template management
- Canvas content serialization/deserialization
- Canvas sharing between devices
- Integration with more advanced drawing features 