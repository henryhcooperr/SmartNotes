# SmartNotes Domain-Driven Design Architecture

This document explains the Domain-Driven Design (DDD) architecture implemented in the SmartNotes application. The restructuring aims to separate concerns properly and create a more maintainable codebase.

## Architecture Overview

The application is structured into the following layers:

### 1. Domain Layer

The Domain layer contains the core business logic and entities without any dependencies on UI or infrastructure. It includes:

- **Domain Models**: Pure data structures that represent business entities (Subject, Note, Page, etc.)
- **Domain Services**: Services that orchestrate operations across multiple domain entities
- **Repository Interfaces**: Abstractions for data persistence operations

### 2. Application Layer

The Application layer coordinates activities between the Domain and Infrastructure layers:

- **Use Cases**: Orchestration of domain operations for specific app features
- **Input/Output Ports**: Interfaces between the domain and presentation layers
- **Dependency Injection**: Container for wiring up the different components

### 3. Infrastructure Layer

The Infrastructure layer provides implementations for domain interfaces:

- **Repository Implementations**: Concrete implementations of domain repositories
- **Persistence Adapters**: Components for data storage (UserDefaults, Core Data, etc.)
- **Framework Adapters**: Adapters for external frameworks (PencilKit, etc.)

### 4. Presentation Layer

The Presentation layer manages UI concerns:

- **View Models**: Transform domain objects for UI consumption
- **Views**: SwiftUI views that bind to view models
- **UI State Management**: Management of UI state separate from domain state

## Key Components

### Domain Models

- `Subject`: Collection of related notes with metadata
- `Note`: Container for pages with metadata
- `Page`: Individual drawing surface with content
- `Template`: Configuration for background rendering
- `DrawingTool`: Configuration for drawing instruments

### Repositories

- `SubjectRepository`: Interface for Subject persistence operations
- `NoteRepository`: Interface for Note persistence operations

### Services

- `NotesManagementService`: Coordination of operations across multiple entities

### Use Cases

- `SubjectUseCases`: Operations related to subjects
- `NoteUseCases`: Operations related to notes

### View Models

- `SubjectListViewModel`: Transforms subjects for the UI list
- `NoteViewModel`: Transforms notes for the UI

## Gradual Migration

The application is being gradually migrated to the new architecture while maintaining backward compatibility with existing code:

1. New code follows the DDD architecture
2. Legacy code continues to function using the old architecture
3. The dependency injection container allows switching between implementations
4. UI components are gradually migrated to use the new architecture

## Benefits of the New Architecture

- **Separation of Concerns**: Clear separation between business logic, UI, and infrastructure
- **Testability**: Domain logic can be tested independently of UI and infrastructure
- **Maintainability**: Changes to one layer don't affect other layers
- **Extensibility**: New features can be added with minimal impact on existing code
- **Domain Focus**: Business concepts are explicitly modeled

## Design Decisions

1. **Repository Pattern**: Used to abstract data access
2. **Immutable Domain Models**: Models use value types with immutable properties
3. **Use Case Pattern**: Application logic is organized into use cases
4. **Reactive Programming**: Combine framework is used for asynchronous operations
5. **Dependency Injection**: Dependencies are injected for better testability
6. **Adapter Pattern**: Used to integrate with external frameworks

## Directory Structure

```
SmartNotes/Core/
├── Domain/
│   ├── Models/         # Domain entities
│   ├── Repositories/   # Repository interfaces
│   └── Services/       # Domain services
├── Application/
│   ├── UseCases/       # Application use cases
│   └── DIContainer.swift  # Dependency injection
├── Infrastructure/
│   └── Persistence/    # Repository implementations
└── Presentation/
    └── ViewModels/     # View models for UI
```

## Example Usage

```swift
// Access the DI container
@Environment(\.diContainer) var diContainer

// Create a view model
let subjectViewModel = diContainer.makeSubjectListViewModel()

// Use the view model in a view
SubjectListView(viewModel: subjectViewModel)
``` 