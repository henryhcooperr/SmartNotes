import Foundation
import Combine

/// Protocol that all events must conform to
public protocol Event {
    /// A unique identifier for this event type
    static var eventName: String { get }
    
    /// A brief description of what this event represents
    static var description: String { get }
}

/// Default implementation for Event protocol
extension Event {
    public static var eventName: String {
        return String(describing: Self.self)
    }
}

/// Main EventBus class that handles type-safe publishing and subscription
public final class EventBus {
    /// Singleton instance for global use
    public static let shared = EventBus()
    
    /// Dictionary of event publishers, keyed by event type name
    private var publishers = [String: Any]()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Publish an event to all subscribers
    /// - Parameter event: The event to publish
    public func publish<T: Event>(_ event: T) {
        let key = T.eventName
        
        // Create the subject if it doesn't exist
        if publishers[key] == nil {
            publishers[key] = PassthroughSubject<T, Never>()
        }
        
        // Get the subject and send the event
        if let subject = publishers[key] as? PassthroughSubject<T, Never> {
            subject.send(event)
        }
    }
    
    /// Subscribe to an event type
    /// - Parameters:
    ///   - eventType: The type of event to subscribe to
    ///   - onReceive: Closure to execute when the event is received
    /// - Returns: AnyCancellable token to manage subscription lifetime
    public func subscribe<T: Event>(_ eventType: T.Type, onReceive: @escaping (T) -> Void) -> AnyCancellable {
        let key = T.eventName
        
        // Create the subject if it doesn't exist
        if publishers[key] == nil {
            publishers[key] = PassthroughSubject<T, Never>()
        }
        
        // Get the subject and subscribe to it
        guard let subject = publishers[key] as? PassthroughSubject<T, Never> else {
            // Should never happen since we just created it if it didn't exist
            return AnyCancellable {}
        }
        
        return subject.sink(receiveValue: onReceive)
    }
    
    /// For debugging purposes - list all event types that have active publishers
    public func listActiveEventTypes() -> [String] {
        return Array(publishers.keys)
    }
    
    /// Clear all subscriptions for a specific event type
    public func clearSubscriptions<T: Event>(for eventType: T.Type) {
        publishers.removeValue(forKey: T.eventName)
    }
    
    /// Clear all subscriptions
    public func clearAllSubscriptions() {
        publishers.removeAll()
    }
}

/// Helper class to store and manage cancellable subscriptions
public final class SubscriptionManager {
    private var cancellables = Set<AnyCancellable>()
    
    public init() {}
    
    /// Store a subscription
    public func store(_ cancellable: AnyCancellable) {
        cancellables.insert(cancellable)
    }
    
    /// Clear all subscriptions
    public func clearAll() {
        cancellables.removeAll()
    }
    
    /// Convenience method to subscribe and automatically store the cancellable
    public func subscribe<T: Event>(_ eventType: T.Type, onReceive: @escaping (T) -> Void) {
        let cancellable = EventBus.shared.subscribe(eventType, onReceive: onReceive)
        store(cancellable)
    }
} 