//
//  PageNavigatorView.swift
//  SmartNotes
//
//  Created on 4/1/25.
//  Updated to use EventStore for state management instead of Binding parameters
//

import SwiftUI
import PencilKit
import UniformTypeIdentifiers

// MARK: - Notification Names
extension NSNotification.Name {
    static let pageReorderingNotification = NSNotification.Name("PageReordering")
}

struct PageNavigatorView: View {
    // Replace Binding parameters with EventStore
    @EnvironmentObject private var eventStore: EventStore
    
    // Note identification
    let noteID: UUID
    
    // Local state management
    @State private var draggedItem: Page?
    @State private var visiblePageIndex: Int = 0  // Track which page is currently visible
    @State private var isSelectionActive: Bool = false
    @State private var selectedPageIndex: Int = 0
    
    // Size constants for the navigator
    private let thumbnailWidth: CGFloat = 120
    private let thumbnailHeight: CGFloat = 160
    private let spacing: CGFloat = 12
    
    // Computed property to get the pages from EventStore
    private var pages: [Page] {
        guard let subjectIndex = eventStore.state.contentState.subjects.firstIndex(where: { 
            $0.id == eventStore.state.contentState.selection.selectedSubjectID 
        }),
        let noteIndex = eventStore.state.contentState.subjects[subjectIndex].notes.firstIndex(where: {
            $0.id == eventStore.state.contentState.selection.selectedNoteID
        }) else {
            return []
        }
        
        return eventStore.state.contentState.subjects[subjectIndex].notes[noteIndex].pages
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Pages")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray6))
            
            ScrollView {
                LazyVStack(spacing: spacing) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        PageThumbnailView(
                            page: page,
                            noteID: noteID,
                            isSelected: index == selectedPageIndex && isSelectionActive,
                            isVisible: index == visiblePageIndex,
                            onTap: {
                                // Always select the page to trigger scrolling
                                selectedPageIndex = index
                                isSelectionActive = true
                                
                                // Dispatch a page selection action
                                eventStore.dispatch(PageAction.selectPage(
                                    pageIndex: index,
                                    pageID: page.id
                                ))
                                
                                // Publish event that page was explicitly selected by user
                                EventBus.shared.publish(PageEvents.PageSelectedByUser(pageIndex: index))
                            },
                            onBookmarkToggle: {
                                toggleBookmark(for: page, index: index)
                            }
                        )
                        .onDrag {
                            self.draggedItem = page
                            return NSItemProvider(object: page.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: PageDropDelegate(
                            item: page,
                            noteID: noteID,
                            eventStore: eventStore,
                            pages: pages,
                            draggedItem: $draggedItem)
                        )
                    }
                }
                .padding()
            }
        }
        .frame(width: thumbnailWidth + 40)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // Get current selection from EventStore
            selectedPageIndex = eventStore.state.contentState.selection.selectedPageIndex
            isSelectionActive = eventStore.state.uiState.isPageSelectionActive
            
            // Force regeneration of thumbnails for all pages
            for page in pages {
                PageThumbnailGenerator.clearCache(for: page.id, noteID: noteID)
            }
        }
        // Listen for page selection notifications from the scroll view
        .onPageSelected { event in
            // Update which page is visible
            visiblePageIndex = event.pageIndex
            
            // Also update selectedPageIndex but don't activate selection
            // This helps coordinate both states for UI consistency
            selectedPageIndex = event.pageIndex
            
            // We don't set isSelectionActive here to prevent scroll changes
            // from triggering navigation logic
        }
        // Add a separate listener for page selection deactivation
        .onPageSelectionDeactivated {
            // Deactivate selection when requested
            isSelectionActive = false
            
            // Update the EventStore
            eventStore.dispatch(NavigationAction.updatePageSelectionActive(isActive: false))
        }
        // Add listener for visible page changes
        .onVisiblePageChanged { event in 
            // Update which page is visible in the navigator
            visiblePageIndex = event.pageIndex
            print("🔍 PageNavigatorView: Visible page changed to \(event.pageIndex + 1)")
        }
        // Listen for page selection changes from EventStore
        .onEvent(PageAction.self) { action in
            switch action {
            case let selectPage as PageAction.selectPage:
                selectedPageIndex = selectPage.pageIndex 
                isSelectionActive = true
            default:
                break
            }
        }
        // Listen for navigation changes from EventStore
        .onEvent(NavigationAction.self) { action in
            if case let NavigationAction.updatePageSelectionActive(isActive) = action {
                isSelectionActive = isActive
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Toggles the bookmark status for a page
    private func toggleBookmark(for page: Page, index: Int) {
        var updatedPage = page
        updatedPage.isBookmarked.toggle()
        
        // Get the current subject and note IDs from EventStore
        if let subjectID = eventStore.state.contentState.selection.selectedSubjectID,
           let noteID = eventStore.state.contentState.selection.selectedNoteID {
            // Use EventStore to update the page
            eventStore.dispatch(PageAction.updatePage(
                updatedPage,
                noteID: noteID,
                subjectID: subjectID
            ))
        }
    }
    
    /// Adds a new page to the end of the pages array
    private func addNewPage() {
        let newPage = Page(
            pageNumber: pages.count + 1
        )
        
        // Get the current subject and note IDs from EventStore
        if let subjectID = eventStore.state.contentState.selection.selectedSubjectID,
           let noteID = eventStore.state.contentState.selection.selectedNoteID {
            // Use EventStore to add the page
            eventStore.dispatch(PageAction.addPage(
                newPage,
                noteID: noteID,
                subjectID: subjectID
            ))
            
            // Select the newly added page
            selectedPageIndex = pages.count // Since the new page will be at the end
            isSelectionActive = true
            
            // Update selection in EventStore
            eventStore.dispatch(PageAction.selectPage(
                pageIndex: selectedPageIndex,
                pageID: newPage.id
            ))
            
            // Publish event that a new page was added
            EventBus.shared.publish(PageEvents.PageAdded(pageId: newPage.id))
            
            // Also post a notification that this page is now selected
            // This ensures the main content view will show the new page
            EventBus.shared.publish(PageEvents.PageSelectedByUser(pageIndex: selectedPageIndex))
        }
    }
}

// MARK: - PageThumbnailView

struct PageThumbnailView: View {
    let page: Page
    let noteID: UUID?
    let isSelected: Bool
    let isVisible: Bool
    let onTap: () -> Void
    let onBookmarkToggle: () -> Void
    
    // Generate thumbnail using PageThumbnailGenerator
    @State private var thumbnail: UIImage?
    @State private var isActivelyDrawing: Bool = false
    @State private var updateTimer: Timer? = nil
    @State private var subscriptionManager = SubscriptionManager()
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: thumbnail ?? PageThumbnailGenerator.generateThumbnail(from: page, noteID: noteID))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 160)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.blue : 
                                (isVisible ? Color.green : Color.gray.opacity(0.3)), 
                                lineWidth: isSelected ? 2 : (isVisible ? 1.5 : 0.5)
                            )
                    )
                    .shadow(color: isSelected ? Color.blue.opacity(0.3) : (isVisible ? Color.green.opacity(0.2) : Color.clear), radius: 4)
                    .overlay(
                        isActivelyDrawing ? 
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 2)
                                .animation(.easeInOut, value: isActivelyDrawing)
                        : nil
                    )
                
                // Bookmark button
                Button(action: onBookmarkToggle) {
                    Image(systemName: page.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(page.isBookmarked ? .yellow : .gray)
                        .padding(6)
                        .background(Color.white.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(6)
            }
            
            Text("Page \(page.pageNumber)")
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 120)
        .padding(4)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            // Load thumbnail when view appears
            loadThumbnail()
            
            // Listen for drawing changes
            subscriptionManager.subscribe(DrawingEvents.PageDrawingChanged.self) { event in
                if event.pageId == page.id {
                    // Reload thumbnail when active drawing occurs
                    loadThumbnail(force: true)
                    isActivelyDrawing = false
                    stopUpdateTimer()
                }
            }
            
            // Listen for live drawing updates
            subscriptionManager.subscribe(DrawingEvents.LiveDrawingUpdate.self) { event in
                if event.pageId == page.id {
                    // During active drawing, we'll use a timer instead of immediate updates
                    isActivelyDrawing = true
                }
            }
            
            // Listen for drawing started notifications
            subscriptionManager.subscribe(DrawingEvents.DrawingStarted.self) { event in
                if event.pageId == page.id {
                    isActivelyDrawing = true
                    startUpdateTimer()
                }
            }
            
            // Listen for thumbnail generated events
            subscriptionManager.subscribe(PageThumbnailGeneratedEvent.self) { event in
                if event.pageID == page.id {
                    // Update the thumbnail when a new one is generated
                    DispatchQueue.main.async {
                        self.thumbnail = event.image
                    }
                }
            }
            
            // Listen for thumbnail invalidated events
            subscriptionManager.subscribe(PageThumbnailInvalidatedEvent.self) { event in
                if event.pageID == page.id {
                    // Reload the thumbnail when it's invalidated
                    loadThumbnail(force: true)
                }
            }
        }
        .onDisappear {
            // Clear subscriptions when view disappears
            subscriptionManager.clearAll()
            stopUpdateTimer()
        }
        .onChange(of: page.drawingData) { _, _ in
            // Reload thumbnail when drawing data changes
            loadThumbnail(force: true)
        }
        .onChange(of: page.isBookmarked) { _, _ in
            // Reload thumbnail when bookmark status changes
            loadThumbnail(force: true)
        }
        .onChange(of: isActivelyDrawing) { _, newValue in
            if newValue {
                startUpdateTimer()
            } else {
                stopUpdateTimer()
            }
        }
    }
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            loadThumbnail(force: true)
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func loadThumbnail(force: Bool = false) {
        Task {
            let image = PageThumbnailGenerator.generateThumbnail(
                from: page,
                noteID: noteID,
                force: force
            )
            
            await MainActor.run {
                self.thumbnail = image
            }
        }
    }
}

// MARK: - PageDropDelegate

struct PageDropDelegate: DropDelegate {
    let item: Page
    let noteID: UUID
    let eventStore: EventStore
    let pages: [Page]
    @Binding var draggedItem: Page?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedItem = draggedItem else { return false }
        
        // Get the final indices after all drag operations are complete
        let finalFromIndex = pages.firstIndex(where: { $0.id == draggedItem.id })!
        let finalToIndex = pages.firstIndex(where: { $0.id == item.id })!
        
        // Post notification about the reordering
        EventBus.shared.publish(PageEvents.PageReordering(fromIndex: finalFromIndex, toIndex: finalToIndex))
        
        // Also dispatch an action to EventStore
        if let subjectID = eventStore.state.contentState.selection.selectedSubjectID,
           let noteID = eventStore.state.contentState.selection.selectedNoteID {
            // Use EventStore to update the page order
            eventStore.dispatch(PageAction.reorderPages(
                fromIndex: finalFromIndex,
                toIndex: finalToIndex,
                noteID: noteID,
                subjectID: subjectID
            ))
        }
        
        // Reset the dragged item
        self.draggedItem = nil
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        
        if draggedItem.id != item.id {
            let from = pages.firstIndex(where: { $0.id == draggedItem.id })!
            let to = pages.firstIndex(where: { $0.id == item.id })!
            
            print("🔄 Moving page from position \(from+1) to \(to+1)")
            
            if pages[to].id != draggedItem.id {
                // Since we can't modify the pages directly anymore, dispatch an action to EventStore
                if let subjectID = eventStore.state.contentState.selection.selectedSubjectID,
                   let noteID = eventStore.state.contentState.selection.selectedNoteID {
                    // Use EventStore to update the page order
                    eventStore.dispatch(PageAction.reorderPages(
                        fromIndex: from,
                        toIndex: to > from ? to + 1 : to,
                        noteID: noteID,
                        subjectID: subjectID
                    ))
                }
                
                // Log the new order for debugging
                print("📄 Requested page reorder:")
                print("   From position \(from+1) to \(to+1)")
            }
        }
    }
} 