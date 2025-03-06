import SwiftUI
import Combine

/// Extension to View that provides convenient event subscription methods
public extension View {
    /// Subscribe to an event type and perform an action when it's received
    /// - Parameters:
    ///   - eventType: The type of event to subscribe to
    ///   - action: The action to perform when the event is received
    /// - Returns: A view that will receive the specified events
    func onEvent<T: Event>(_ eventType: T.Type, perform action: @escaping (T) -> Void) -> some View {
        self.modifier(EventSubscriberModifier(eventType: eventType, action: action))
    }
}

/// View modifier that subscribes to events using EventBus
public struct EventSubscriberModifier<T: Event>: ViewModifier {
    /// The type of event to subscribe to
    let eventType: T.Type
    
    /// The action to perform when the event is received
    let action: (T) -> Void
    
    /// Store for the subscription
    @State private var subscription: AnyCancellable?
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                // Subscribe to the event when the view appears
                subscription = EventBus.shared.subscribe(eventType) { event in
                    action(event)
                }
            }
            .onDisappear {
                // Cancel the subscription when the view disappears
                subscription?.cancel()
                subscription = nil
            }
    }
}

/// Collection of convenient subscription methods for specific event types
public extension View {
    /// Subscribe to page selection events
    func onPageSelected(perform action: @escaping (PageEvents.PageSelected) -> Void) -> some View {
        onEvent(PageEvents.PageSelected.self, perform: action)
    }
    
    /// Subscribe to user-initiated page selection events
    func onPageSelectedByUser(perform action: @escaping (PageEvents.PageSelectedByUser) -> Void) -> some View {
        onEvent(PageEvents.PageSelectedByUser.self, perform: action)
    }
    
    /// Subscribe to page selection deactivation events
    func onPageSelectionDeactivated(perform action: @escaping () -> Void) -> some View {
        onEvent(PageEvents.PageSelectionDeactivated.self) { _ in
            action()
        }
    }
    
    /// Subscribe to page added events
    func onPageAdded(perform action: @escaping (PageEvents.PageAdded) -> Void) -> some View {
        onEvent(PageEvents.PageAdded.self, perform: action)
    }
    
    /// Subscribe to page reordering events
    func onPageReordering(perform action: @escaping (PageEvents.PageReordering) -> Void) -> some View {
        onEvent(PageEvents.PageReordering.self, perform: action)
    }
    
    /// Subscribe to page visibility change events
    func onVisiblePageChanged(perform action: @escaping (PageEvents.VisiblePageChanged) -> Void) -> some View {
        onEvent(PageEvents.VisiblePageChanged.self, perform: action)
    }
    
    /// Subscribe to scroll to page requests
    func onScrollToPage(perform action: @escaping (PageEvents.ScrollToPage) -> Void) -> some View {
        onEvent(PageEvents.ScrollToPage.self, perform: action)
    }
    
    /// Subscribe to drawing change events
    func onPageDrawingChanged(perform action: @escaping (DrawingEvents.PageDrawingChanged) -> Void) -> some View {
        onEvent(DrawingEvents.PageDrawingChanged.self, perform: action)
    }
    
    /// Subscribe to live drawing update events
    func onLiveDrawingUpdate(perform action: @escaping (DrawingEvents.LiveDrawingUpdate) -> Void) -> some View {
        onEvent(DrawingEvents.LiveDrawingUpdate.self, perform: action)
    }
    
    /// Subscribe to drawing started events
    func onDrawingStarted(perform action: @escaping (DrawingEvents.DrawingStarted) -> Void) -> some View {
        onEvent(DrawingEvents.DrawingStarted.self, perform: action)
    }
    
    /// Subscribe to drawing completed events
    func onDrawingCompleted(perform action: @escaping (DrawingEvents.DrawingDidComplete) -> Void) -> some View {
        onEvent(DrawingEvents.DrawingDidComplete.self, perform: action)
    }
    
    /// Subscribe to template refresh requests
    func onRefreshTemplate(perform action: @escaping () -> Void) -> some View {
        onEvent(TemplateEvents.RefreshTemplate.self) { _ in
            action()
        }
    }
    
    /// Subscribe to force template refresh requests
    func onForceTemplateRefresh(perform action: @escaping () -> Void) -> some View {
        onEvent(TemplateEvents.ForceTemplateRefresh.self) { _ in
            action()
        }
    }
    
    /// Subscribe to template changed events
    func onTemplateChanged(perform action: @escaping (TemplateEvents.TemplateChanged) -> Void) -> some View {
        onEvent(TemplateEvents.TemplateChanged.self, perform: action)
    }
    
    /// Subscribe to sidebar visibility change events
    func onSidebarVisibilityChanged(perform action: @escaping (UIEvents.SidebarVisibilityChanged) -> Void) -> some View {
        onEvent(UIEvents.SidebarVisibilityChanged.self, perform: action)
    }
    
    /// Subscribe to grid state change events
    func onGridStateChanged(perform action: @escaping (GridEvents.GridStateChanged) -> Void) -> some View {
        onEvent(GridEvents.GridStateChanged.self, perform: action)
    }
    
    /// Subscribe to coordinator ready events
    func onCoordinatorReady(perform action: @escaping (SystemEvents.CoordinatorReady) -> Void) -> some View {
        onEvent(SystemEvents.CoordinatorReady.self, perform: action)
    }
}

/// Convenience extension to help with subscription in UIKit components
public extension NSObject {
    /// Property to store subscription manager
    private static var subscriptionManagerKey = "subscriptionManagerKey"
    
    /// Access to the subscription manager
    var subscriptionManager: SubscriptionManager {
        // Get the existing manager or create a new one
        if let manager = objc_getAssociatedObject(self, &NSObject.subscriptionManagerKey) as? SubscriptionManager {
            return manager
        }
        
        let manager = SubscriptionManager()
        objc_setAssociatedObject(self, &NSObject.subscriptionManagerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return manager
    }
} 