import Foundation
import Combine

/// Error event published by the error handling middleware
struct AppError: Event {
    static var description: String = "Application error event"
    
    /// The error that occurred
    let error: Error
    
    /// The action that caused the error
    let sourceAction: Action
    
    /// Context information for debugging
    let context: String
    
    /// Timestamp of the error
    let timestamp: Date
    
    /// Creates a new AppError event
    init(error: Error, sourceAction: Action, context: String) {
        self.error = error
        self.sourceAction = sourceAction
        self.context = context
        self.timestamp = Date()
    }
}

/// Middleware that handles error reporting and tracking
class ErrorHandlingMiddleware {
    private let eventBus = EventBus.shared
    private var errors: [AppError] = []
    private let maxStoredErrors = 100
    
    /// Creates a new ErrorHandlingMiddleware
    init() {}
    
    /// The middleware function that will be called for each action
    func middleware(state: AppState, action: Action) {
        // This middleware doesn't do anything proactively, but is called
        // by other parts of the app when errors occur
    }
    
    /// Report an error that occurred during action processing
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - action: The action that was being processed
    ///   - context: Additional context about where the error occurred
    func reportError(error: Error, action: Action, context: String) {
        let appError = AppError(error: error, sourceAction: action, context: context)
        
        // Store the error
        errors.append(appError)
        if errors.count > maxStoredErrors {
            errors.removeFirst()
        }
        
        // Log the error
        print("❌ ERROR: \(error.localizedDescription)")
        print("   Action: \(action.description)")
        print("   Context: \(context)")
        
        // Publish the error event
        eventBus.publish(appError)
    }
    
    /// Get the most recent errors
    /// - Parameter count: The maximum number of errors to return
    /// - Returns: The most recent errors
    func getRecentErrors(count: Int = 10) -> [AppError] {
        let requestedCount = min(count, errors.count)
        return Array(errors.suffix(requestedCount))
    }
    
    /// Clear the error history
    func clearErrors() {
        errors.removeAll()
    }
} 