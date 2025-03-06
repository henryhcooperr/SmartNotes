import Foundation
import Combine

/// NotificationBridge provides backward compatibility between the new EventBus and legacy NotificationCenter.
/// This facilitates a gradual migration path where components can be updated incrementally.
public final class NotificationBridge {
    /// Singleton instance
    public static let shared = NotificationBridge()
    
    /// Store for cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Dictionary mapping event types to notification names
    private let eventToNotificationMap: [String: NSNotification.Name] = [
        // Page Events
        String(describing: PageEvents.PageSelected.self): NSNotification.Name("PageSelected"),
        String(describing: PageEvents.PageSelectedByUser.self): NSNotification.Name("PageSelectedByUser"),
        String(describing: PageEvents.PageSelectionDeactivated.self): NSNotification.Name("PageSelectionDeactivated"),
        String(describing: PageEvents.PageAdded.self): NSNotification.Name("PageAdded"),
        String(describing: PageEvents.PageReordering.self): NSNotification.Name.pageReorderingNotification,
        String(describing: PageEvents.VisiblePageChanged.self): NSNotification.Name("VisiblePageChanged"),
        String(describing: PageEvents.ScrollToPage.self): NSNotification.Name("ScrollToPage"),
        
        // Drawing Events
        String(describing: DrawingEvents.PageDrawingChanged.self): NSNotification.Name("PageDrawingChanged"),
        String(describing: DrawingEvents.LiveDrawingUpdate.self): NSNotification.Name("LiveDrawingUpdate"),
        String(describing: DrawingEvents.DrawingStarted.self): NSNotification.Name("DrawingStarted"),
        String(describing: DrawingEvents.DrawingDidComplete.self): NSNotification.Name("DrawingDidComplete"),
        
        // Template Events
        String(describing: TemplateEvents.RefreshTemplate.self): NSNotification.Name("RefreshTemplate"),
        String(describing: TemplateEvents.ForceTemplateRefresh.self): NSNotification.Name("ForceTemplateRefresh"),
        String(describing: TemplateEvents.TemplateChanged.self): NSNotification.Name("TemplateChanged"),
        
        // UI Events
        String(describing: UIEvents.SidebarVisibilityChanged.self): NSNotification.Name("SidebarVisibilityChanged"),
        String(describing: UIEvents.CloseSidebar.self): NSNotification.Name("CloseSidebar"),
        String(describing: UIEvents.ToggleSidebar.self): NSNotification.Name("ToggleSidebar"),
        
        // Grid Events
        String(describing: GridEvents.GridStateChanged.self): NSNotification.Name("GridStateChanged"),
        String(describing: GridEvents.ToggleCoordinateGrid.self): NSNotification.Name("ToggleCoordinateGrid"),
        
        // System Events
        String(describing: SystemEvents.DebugModeChanged.self): NSNotification.Name("DebugModeChanged"),
        String(describing: SystemEvents.AutoScrollSettingChanged.self): NSNotification.Name("AutoScrollSettingChanged"),
        String(describing: SystemEvents.CoordinatorReady.self): NSNotification.Name("CoordinatorReady")
    ]
    
    /// Private initializer to enforce singleton pattern
    private init() {
        setupBridges()
    }
    
    /// Set up bridges in both directions:
    /// 1. EventBus to NotificationCenter - for updated components publishing to legacy components
    /// 2. NotificationCenter to EventBus - for legacy components publishing to updated components
    private func setupBridges() {
        // For each event type, create bridges in both directions
        for (eventTypeName, notificationName) in eventToNotificationMap {
            setupBridgeFromEventBus(eventTypeName: eventTypeName, notificationName: notificationName)
            setupBridgeFromNotificationCenter(eventTypeName: eventTypeName, notificationName: notificationName)
        }
    }
    
    /// Set up bridge from EventBus to NotificationCenter for a specific event type
    private func setupBridgeFromEventBus(eventTypeName: String, notificationName: NSNotification.Name) {
        // This is more complex and will require dynamic handling at runtime
        // We'll implement specific bridges for each event type as components are migrated
    }
    
    /// Set up bridge from NotificationCenter to EventBus for a specific notification name
    private func setupBridgeFromNotificationCenter(eventTypeName: String, notificationName: NSNotification.Name) {
        // Subscribe to the notification and convert it to the corresponding event
        // This is done generically here, but event-specific conversion is handled separately
        NotificationCenter.default.publisher(for: notificationName)
            .sink { [weak self] notification in
                self?.convertAndPublishEventFromNotification(
                    notification: notification,
                    eventTypeName: eventTypeName
                )
            }
            .store(in: &cancellables)
    }
    
    /// Convert a notification to an event and publish it on the EventBus
    private func convertAndPublishEventFromNotification(notification: Notification, eventTypeName: String) {
        // Handle each event type specifically based on its payload structure
        switch eventTypeName {
        case String(describing: PageEvents.PageSelected.self):
            if let pageIndex = notification.object as? Int {
                EventBus.shared.publish(PageEvents.PageSelected(pageIndex: pageIndex))
            }
            
        case String(describing: PageEvents.PageSelectedByUser.self):
            if let pageIndex = notification.object as? Int {
                EventBus.shared.publish(PageEvents.PageSelectedByUser(pageIndex: pageIndex))
            }
            
        case String(describing: PageEvents.PageSelectionDeactivated.self):
            EventBus.shared.publish(PageEvents.PageSelectionDeactivated())
            
        case String(describing: PageEvents.PageAdded.self):
            if let pageId = notification.object as? UUID {
                EventBus.shared.publish(PageEvents.PageAdded(pageId: pageId))
            }
            
        case String(describing: PageEvents.PageReordering.self):
            if let userInfo = notification.userInfo,
               let fromIndex = userInfo["fromIndex"] as? Int,
               let toIndex = userInfo["toIndex"] as? Int {
                EventBus.shared.publish(PageEvents.PageReordering(fromIndex: fromIndex, toIndex: toIndex))
            }
            
        case String(describing: PageEvents.VisiblePageChanged.self):
            if let pageIndex = notification.object as? Int {
                EventBus.shared.publish(PageEvents.VisiblePageChanged(pageIndex: pageIndex))
            }
            
        case String(describing: PageEvents.ScrollToPage.self):
            if let pageIndex = notification.object as? Int {
                EventBus.shared.publish(PageEvents.ScrollToPage(pageIndex: pageIndex))
            }
            
        case String(describing: DrawingEvents.PageDrawingChanged.self):
            if let pageId = notification.object as? UUID {
                EventBus.shared.publish(DrawingEvents.PageDrawingChanged(pageId: pageId))
            }
            
        case String(describing: DrawingEvents.LiveDrawingUpdate.self):
            if let pageId = notification.object as? UUID {
                EventBus.shared.publish(DrawingEvents.LiveDrawingUpdate(pageId: pageId))
            }
            
        case String(describing: DrawingEvents.DrawingStarted.self):
            if let pageId = notification.object as? UUID {
                EventBus.shared.publish(DrawingEvents.DrawingStarted(pageId: pageId))
            }
            
        case String(describing: DrawingEvents.DrawingDidComplete.self):
            if let pageId = notification.object as? UUID {
                EventBus.shared.publish(DrawingEvents.DrawingDidComplete(pageId: pageId))
            }
            
        case String(describing: TemplateEvents.RefreshTemplate.self):
            EventBus.shared.publish(TemplateEvents.RefreshTemplate())
            
        case String(describing: TemplateEvents.ForceTemplateRefresh.self):
            EventBus.shared.publish(TemplateEvents.ForceTemplateRefresh())
            
        case String(describing: TemplateEvents.TemplateChanged.self):
            if let templateData = notification.userInfo?["template"] as? Data {
                print("🔄 NotificationBridge: Template data received, size: \(templateData.count) bytes")
                do {
                    let template = try JSONDecoder().decode(CanvasTemplate.self, from: templateData)
                    print("🔄 NotificationBridge: Successfully decoded template type: \(template.type.rawValue)")
                    EventBus.shared.publish(TemplateEvents.TemplateChanged(template: template))
                } catch {
                    print("❌ NotificationBridge: Failed to decode template: \(error)")
                }
            } else {
                print("❌ NotificationBridge: No template data in notification userInfo")
            }
            
        case String(describing: UIEvents.SidebarVisibilityChanged.self):
            if let isVisible = notification.object as? Bool {
                EventBus.shared.publish(UIEvents.SidebarVisibilityChanged(isVisible: isVisible))
            }
            
        case String(describing: UIEvents.CloseSidebar.self):
            EventBus.shared.publish(UIEvents.CloseSidebar())
            
        case String(describing: UIEvents.ToggleSidebar.self):
            EventBus.shared.publish(UIEvents.ToggleSidebar())
            
        case String(describing: GridEvents.GridStateChanged.self):
            if let isVisible = notification.object as? Bool {
                EventBus.shared.publish(GridEvents.GridStateChanged(isVisible: isVisible))
            }
            
        case String(describing: GridEvents.ToggleCoordinateGrid.self):
            EventBus.shared.publish(GridEvents.ToggleCoordinateGrid())
            
        case String(describing: SystemEvents.DebugModeChanged.self):
            if let isEnabled = notification.object as? Bool {
                EventBus.shared.publish(SystemEvents.DebugModeChanged(isEnabled: isEnabled))
            }
            
        case String(describing: SystemEvents.AutoScrollSettingChanged.self):
            if let isEnabled = notification.object as? Bool {
                EventBus.shared.publish(SystemEvents.AutoScrollSettingChanged(isEnabled: isEnabled))
            }
            
        case String(describing: SystemEvents.CoordinatorReady.self):
            if let coordinator = notification.object {
                EventBus.shared.publish(SystemEvents.CoordinatorReady(coordinator: coordinator))
            }
            
        default:
            break
        }
    }
    
    /// Published a specific event type on the legacy notification system
    public func publishEventToNotificationCenter<T: Event>(_ event: T) {
        let eventTypeName = String(describing: type(of: event))
        guard let notificationName = eventToNotificationMap[eventTypeName] else {
            return
        }
        
        // Convert event to notification object and userInfo based on event type
        var object: Any? = nil
        var userInfo: [AnyHashable: Any]? = nil
        
        switch event {
        case let pageSelected as PageEvents.PageSelected:
            object = pageSelected.pageIndex
            
        case let pageSelectedByUser as PageEvents.PageSelectedByUser:
            object = pageSelectedByUser.pageIndex
            
        case is PageEvents.PageSelectionDeactivated:
            object = nil
            
        case let pageAdded as PageEvents.PageAdded:
            object = pageAdded.pageId
            
        case let pageReordering as PageEvents.PageReordering:
            userInfo = [
                "fromIndex": pageReordering.fromIndex,
                "toIndex": pageReordering.toIndex
            ]
            
        case let visiblePageChanged as PageEvents.VisiblePageChanged:
            object = visiblePageChanged.pageIndex
            
        case let scrollToPage as PageEvents.ScrollToPage:
            object = scrollToPage.pageIndex
            
        case let pageDrawingChanged as DrawingEvents.PageDrawingChanged:
            object = pageDrawingChanged.pageId
            
        case let liveDrawingUpdate as DrawingEvents.LiveDrawingUpdate:
            object = liveDrawingUpdate.pageId
            
        case let drawingStarted as DrawingEvents.DrawingStarted:
            object = drawingStarted.pageId
            
        case let drawingDidComplete as DrawingEvents.DrawingDidComplete:
            object = drawingDidComplete.pageId
            
        case is TemplateEvents.RefreshTemplate:
            object = nil
            
        case is TemplateEvents.ForceTemplateRefresh:
            object = nil
            
        case let templateChanged as TemplateEvents.TemplateChanged:
            // Encode the template before sending in the notification
            do {
                let data = try JSONEncoder().encode(templateChanged.template)
                print("🔄 NotificationBridge: Publishing TemplateChanged event with template type: \(templateChanged.template.type.rawValue), data size: \(data.count) bytes")
                userInfo = ["template": data]
            } catch {
                print("❌ NotificationBridge: Failed to encode template: \(error)")
            }
            
        case let sidebarVisibilityChanged as UIEvents.SidebarVisibilityChanged:
            object = sidebarVisibilityChanged.isVisible
            
        case is UIEvents.CloseSidebar:
            object = nil
            
        case is UIEvents.ToggleSidebar:
            object = nil
            
        case let gridStateChanged as GridEvents.GridStateChanged:
            object = gridStateChanged.isVisible
            
        case is GridEvents.ToggleCoordinateGrid:
            object = nil
            
        case let debugModeChanged as SystemEvents.DebugModeChanged:
            object = debugModeChanged.isEnabled
            
        case let autoScrollSettingChanged as SystemEvents.AutoScrollSettingChanged:
            object = autoScrollSettingChanged.isEnabled
            
        case let coordinatorReady as SystemEvents.CoordinatorReady:
            object = coordinatorReady.coordinator
            
        default:
            break
        }
        
        // Post the notification
        NotificationCenter.default.post(name: notificationName, object: object, userInfo: userInfo)
    }
} 