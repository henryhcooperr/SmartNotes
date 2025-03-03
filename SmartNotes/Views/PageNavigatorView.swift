//
//  PageNavigatorView.swift
//  SmartNotes
//
//  Created on 4/1/25.
//

import SwiftUI
import PencilKit

struct PageNavigatorView: View {
    @Binding var pages: [Page]
    @Binding var selectedPageIndex: Int
    @Binding var isSelectionActive: Bool
    @State private var draggedItem: Page?
    
    // Size constants for the navigator
    private let thumbnailWidth: CGFloat = 120
    private let thumbnailHeight: CGFloat = 160
    private let spacing: CGFloat = 12
    
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
                            isSelected: index == selectedPageIndex && isSelectionActive,
                            onTap: {
                                // Always select the page to trigger scrolling
                                selectedPageIndex = index
                                isSelectionActive = true
                            },
                            onBookmarkToggle: {
                                toggleBookmark(for: index)
                            }
                        )
                        .onDrag {
                            self.draggedItem = page
                            return NSItemProvider(object: page.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: PageDropDelegate(
                            item: page,
                            items: $pages,
                            draggedItem: $draggedItem)
                        )
                    }
                    
                    Button(action: addNewPage) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Page")
                        }
                        .padding()
                        .frame(width: thumbnailWidth, height: 44)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
        }
        .frame(width: thumbnailWidth + 40)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // Force regeneration of thumbnails for all pages
            for page in pages {
                PageThumbnailGenerator.clearCache(for: page.id)
            }
        }
        .onChange(of: pages) { _, _ in
            // Ensure page numbers are updated correctly
            for (index, _) in pages.enumerated() {
                pages[index].pageNumber = index + 1
            }
        }
        // Listen for page selection notifications from the scroll view
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PageSelected"))) { notification in
            if let pageIndex = notification.object as? Int {
                // Only update the index but don't activate selection
                // This allows highlighting which page is visible without navigating
                selectedPageIndex = pageIndex
                
                // We don't set isSelectionActive here to prevent scroll changes
                // from triggering navigation logic
            }
        }
        // Add a separate listener for page selection deactivation
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PageSelectionDeactivated"))) { _ in
            // Deactivate selection when requested
            isSelectionActive = false
        }
    }
    
    // MARK: - Helper Methods
    
    /// Toggles the bookmark status for a page at the given index
    private func toggleBookmark(for index: Int) {
        guard index < pages.count else { return }
        pages[index].isBookmarked.toggle()
    }
    
    /// Adds a new page to the end of the pages array
    private func addNewPage() {
        let newPage = Page(
            pageNumber: pages.count + 1
        )
        pages.append(newPage)
    }
}

// MARK: - PageThumbnailView

struct PageThumbnailView: View {
    let page: Page
    let isSelected: Bool
    let onTap: () -> Void
    let onBookmarkToggle: () -> Void
    
    // Generate thumbnail using PageThumbnailGenerator
    @State private var thumbnail: UIImage?
    @State private var isActivelyDrawing: Bool = false
    @State private var updateTimer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: thumbnail ?? PageThumbnailGenerator.generateThumbnail(from: page))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 160)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 0.5)
                    )
                    .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 4)
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
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("PageDrawingChanged"),
                object: nil,
                queue: .main
            ) { notification in
                // Check if this notification is for our page
                if let pageID = notification.object as? UUID, pageID == page.id {
                    // Reload thumbnail when active drawing occurs
                    loadThumbnail(force: true)
                    isActivelyDrawing = false
                    stopUpdateTimer()
                }
            }
            
            // Listen for live drawing updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("LiveDrawingUpdate"),
                object: nil,
                queue: .main
            ) { notification in
                // Check if this notification is for our page
                if let pageID = notification.object as? UUID, pageID == page.id {
                    // During active drawing, we'll use a timer instead of immediate updates
                    isActivelyDrawing = true
                }
            }
            
            // Listen for drawing started notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("DrawingStarted"),
                object: nil,
                queue: .main
            ) { notification in
                // Check if this notification is for our page
                if let pageID = notification.object as? UUID, pageID == page.id {
                    isActivelyDrawing = true
                    startUpdateTimer()
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(self)
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
    @Binding var items: [Page]
    @Binding var draggedItem: Page?
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        
        if draggedItem.id != item.id {
            let from = items.firstIndex(where: { $0.id == draggedItem.id })!
            let to = items.firstIndex(where: { $0.id == item.id })!
            
            if items[to].id != draggedItem.id {
                withAnimation {
                    items.move(fromOffsets: IndexSet(integer: from),
                            toOffset: to > from ? to + 1 : to)
                }
                
                // Update page numbers
                for i in 0..<items.count {
                    items[i].pageNumber = i + 1
                }
            }
        }
    }
} 