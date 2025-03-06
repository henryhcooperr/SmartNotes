import Foundation
import PencilKit

// MARK: - Page Navigation Events

/// Events related to page navigation and selection
public enum PageEvents {
    /// Event fired when a page is selected
    public struct PageSelected: Event {
        public static let description = "Fired when a page is selected, either programmatically or by user"
        
        /// The index of the selected page
        public let pageIndex: Int
        
        public init(pageIndex: Int) {
            self.pageIndex = pageIndex
        }
    }
    
    /// Event fired when a page is explicitly selected by the user (via thumbnail)
    public struct PageSelectedByUser: Event {
        public static let description = "Fired when a page is explicitly selected by the user via the thumbnail"
        
        /// The index of the selected page
        public let pageIndex: Int
        
        public init(pageIndex: Int) {
            self.pageIndex = pageIndex
        }
    }
    
    /// Event fired when page selection is deactivated
    public struct PageSelectionDeactivated: Event {
        public static let description = "Fired when page selection is deactivated, allowing free scrolling"
        
        public init() {}
    }
    
    /// Event fired when a new page is added
    public struct PageAdded: Event {
        public static let description = "Fired when a new page is added to the note"
        
        /// The ID of the newly added page
        public let pageId: UUID
        
        public init(pageId: UUID) {
            self.pageId = pageId
        }
    }
    
    /// Event fired when pages are reordered
    public struct PageReordering: Event {
        public static let description = "Fired when pages are reordered via drag and drop"
        
        /// The original index of the page that was moved
        public let fromIndex: Int
        
        /// The new index where the page was moved to
        public let toIndex: Int
        
        public init(fromIndex: Int, toIndex: Int) {
            self.fromIndex = fromIndex
            self.toIndex = toIndex
        }
    }
    
    /// Event fired when the visible page changes during scrolling
    public struct VisiblePageChanged: Event {
        public static let description = "Fired when the visible page changes during scrolling"
        
        /// The index of the now-visible page
        public let pageIndex: Int
        
        public init(pageIndex: Int) {
            self.pageIndex = pageIndex
        }
    }
    
    /// Event fired to request scrolling to a specific page
    public struct ScrollToPage: Event {
        public static let description = "Request to scroll to a specific page"
        
        /// The index of the page to scroll to
        public let pageIndex: Int
        
        public init(pageIndex: Int) {
            self.pageIndex = pageIndex
        }
    }
}

// MARK: - Drawing Events

/// Events related to drawing and canvas interactions
public enum DrawingEvents {
    /// Event fired when a page's drawing changes
    public struct PageDrawingChanged: Event {
        public static let description = "Fired when a page's drawing is modified and saved"
        
        /// The ID of the page that changed
        public let pageId: UUID
        
        /// The updated drawing data
        public let drawingData: Data?
        
        public init(pageId: UUID, drawingData: Data? = nil) {
            self.pageId = pageId
            self.drawingData = drawingData
        }
    }
    
    /// Event fired when a drawing is in progress (live updates)
    public struct LiveDrawingUpdate: Event {
        public static let description = "Fired during active drawing to provide frequent updates"
        
        /// The ID of the page being drawn on
        public let pageId: UUID
        
        public init(pageId: UUID) {
            self.pageId = pageId
        }
    }
    
    /// Event fired when drawing begins on a page
    public struct DrawingStarted: Event {
        public static let description = "Fired when drawing begins on a page"
        
        /// The ID of the page being drawn on
        public let pageId: UUID
        
        public init(pageId: UUID) {
            self.pageId = pageId
        }
    }
    
    /// Event fired when drawing is completed on a page
    public struct DrawingDidComplete: Event {
        public static let description = "Fired when drawing is completed on a page"
        
        /// The ID of the page that was drawn on
        public let pageId: UUID
        
        public init(pageId: UUID) {
            self.pageId = pageId
        }
    }
}

// MARK: - Template Events

/// Events related to template management
public enum TemplateEvents {
    /// Event fired to request a template refresh
    public struct RefreshTemplate: Event {
        public static let description = "Request to refresh the current template"
        
        public init() {}
    }
    
    /// Event fired to force a complete template refresh
    public struct ForceTemplateRefresh: Event {
        public static let description = "Request to force a complete template refresh"
        
        public init() {}
    }
    
    /// Event fired when a template has been changed
    public struct TemplateChanged: Event {
        public static let description = "Fired when a template has been changed"
        
        /// The updated template
        public let template: CanvasTemplate
        
        public init(template: CanvasTemplate) {
            self.template = template
        }
    }
}

// MARK: - UI Events

/// Events related to UI state changes
public enum UIEvents {
    /// Event fired when the sidebar visibility changes
    public struct SidebarVisibilityChanged: Event {
        public static let description = "Fired when the sidebar visibility changes"
        
        /// Whether the sidebar is now visible
        public let isVisible: Bool
        
        public init(isVisible: Bool) {
            self.isVisible = isVisible
        }
    }
    
    /// Event fired to request the sidebar be closed
    public struct CloseSidebar: Event {
        public static let description = "Request to close the sidebar"
        
        public init() {}
    }
    
    /// Event fired to request toggling the sidebar
    public struct ToggleSidebar: Event {
        public static let description = "Request to toggle the sidebar visibility"
        
        public init() {}
    }
}

// MARK: - Grid Events

/// Events related to the coordinate grid
public enum GridEvents {
    /// Event fired when the grid state changes
    public struct GridStateChanged: Event {
        public static let description = "Fired when the grid visibility state changes"
        
        /// Whether the grid is now visible
        public let isVisible: Bool
        
        public init(isVisible: Bool) {
            self.isVisible = isVisible
        }
    }
    
    /// Event fired to request toggling the coordinate grid
    public struct ToggleCoordinateGrid: Event {
        public static let description = "Request to toggle the coordinate grid visibility"
        
        public init() {}
    }
}

// MARK: - Tool Events

/// Events related to drawing tools
public enum ToolEvents {
    /// Event fired when a tool changes
    public struct ToolChanged: Event {
        public static let description = "Fired when a drawing tool is changed"
        
        /// The tool type
        public let tool: PKInkingTool.InkType
        
        /// The tool color
        public let color: UIColor
        
        /// The tool width
        public let width: CGFloat
        
        public init(tool: PKInkingTool.InkType, color: UIColor, width: CGFloat) {
            self.tool = tool
            self.color = color
            self.width = width
        }
    }
}

// MARK: - System Events

/// Events related to system-wide state changes
public enum SystemEvents {
    /// Event fired when debug mode changes
    public struct DebugModeChanged: Event {
        public static let description = "Fired when debug mode is enabled or disabled"
        
        /// Whether debug mode is now enabled
        public let isEnabled: Bool
        
        public init(isEnabled: Bool) {
            self.isEnabled = isEnabled
        }
    }
    
    /// Event fired when auto-scroll settings change
    public struct AutoScrollSettingChanged: Event {
        public static let description = "Fired when auto-scroll settings are modified"
        
        /// Whether auto-scroll is now enabled
        public let isEnabled: Bool
        
        public init(isEnabled: Bool) {
            self.isEnabled = isEnabled
        }
    }
    
    /// Event fired when the coordinator is ready
    public struct CoordinatorReady: Event {
        public static let description = "Fired when the MultiPageUnifiedScrollView coordinator is ready"
        
        /// The coordinator object
        public let coordinator: Any
        
        public init(coordinator: Any) {
            self.coordinator = coordinator
        }
    }
} 