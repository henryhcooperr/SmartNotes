//
//  NoteDetailView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//  Updated on 3/6/25 to support a single, note-wide template and unified multi-page
//  Updated on 2/27/25 to fix template persistence issues
//  Updated on 4/1/25 to add PageNavigatorView sidebar
//  Updated to use EventStore for state management
//

import SwiftUI
import PencilKit

struct NoteDetailView: View {
    // Replace direct note binding with EventStore state management
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var dataManager: DataManager // Keep for backward compatibility during transition
    
    // Note identification
    let noteIndex: Int
    let subjectID: UUID
    
    // Local UI state
    @State private var showingTemplateSheet = false
    @State private var localTitle: String = ""
    @State private var isInitialLoad = true
    @State private var showExportOptions = false
    @State private var noteTemplate: CanvasTemplate = .none
    @State private var showingTemplateSettings = false
    @State private var isDrawingActive = false
    @State private var isPageNavigatorVisible = false
    @State private var selectedPageIndex = 0
    @State private var isPageSelectionActive = false
    @State private var selectedTool: PKInkingTool.InkType = .pen
    @State private var selectedColor: Color = .black
    @State private var lineWidth: CGFloat = 2.0
    @State private var showCustomToolbar = true
    @State private var scrollViewCoordinator: MultiPageUnifiedScrollView.Coordinator?
    
    // Environment for dismissing the view (keeping for compatibility)
    @Environment(\.presentationMode) var presentationMode
    
    // Computed properties to access the current note from state
    private var subject: Subject? {
        eventStore.state.contentState.subjects.first(where: { $0.id == subjectID })
    }
    
    private var note: Note? {
        guard let subject = subject, noteIndex < subject.notes.count else { return nil }
        return subject.notes[noteIndex]
    }
    
    // Binding for the current note's pages
    private var notePagesBinding: Binding<[Page]> {
        Binding<[Page]>(
            get: {
                self.note?.pages ?? []
            },
            set: { newPages in
                if let note = self.note {
                    let updatedNote = note.copyWith(pages: newPages)
                    self.eventStore.dispatch(NoteAction.updateNote(
                        updatedNote,
                        subjectID: self.subjectID
                    ))
                }
            }
        )
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Page Navigator Sidebar
            if isPageNavigatorVisible {
                PageNavigatorView(
                    pages: notePagesBinding,
                    selectedPageIndex: $selectedPageIndex,
                    isSelectionActive: $isPageSelectionActive
                )
                .transition(.move(edge: .leading))
                
                Divider()
            }
            
            // Main Content
            VStack(spacing: 0) {
                // Custom Navigation Bar
                CustomNavigationBar(
                    title: $localTitle,
                    onBack: {
                        // Navigate back using EventStore action
                        eventStore.dispatch(NavigationAction.navigateToSubjectsList)
                    },
                    onToggleSidebar: {
                        withAnimation {
                            isPageNavigatorVisible.toggle()
                        }
                    },
                    onShowTemplateSettings: {
                        showingTemplateSettings = true
                    },
                    onShowExport: {
                        showExportOptions = true
                    },
                    onTitleChanged: { newTitle in
                        // Only update the note model after initial load
                        if !isInitialLoad, let currentNote = note {
                            let updatedNote = currentNote.copyWith(title: newTitle)
                            eventStore.dispatch(NoteAction.updateNote(
                                updatedNote,
                                subjectID: subjectID
                            ))
                        }
                    }
                )
                
                // Unified multi-page scroll
                ZStack {
                    MultiPageUnifiedScrollView(pages: notePagesBinding, template: $noteTemplate)
                        .sheet(isPresented: $showingTemplateSheet) {
                            TemplateSettingsView(template: $noteTemplate)
                        }
                        .onAppear {
                            guard let currentNote = note else {
                                print("⚠️ NoteDetailView appeared but note is nil")
                                return
                            }
                            
                            print("📝 NoteDetailView appeared for note ID: \(currentNote.id)")
                            
                            // Initialize local title from the note
                            localTitle = currentNote.title
                            
                            // CRITICAL FIX: Ensure there's at least one page for new notes
                            if currentNote.pages.isEmpty {
                                print("📝 Creating initial empty page for new note")
                                let newPage = Page(
                                    drawingData: Data(),
                                    template: nil,
                                    pageNumber: 1
                                )
                                
                                let updatedNote = currentNote.copyWith(pages: [newPage])
                                eventStore.dispatch(NoteAction.updateNote(
                                    updatedNote,
                                    subjectID: subjectID
                                ))
                            }
                            
                            // Get template from note
                            if let savedTemplate = currentNote.noteTemplate {
                                noteTemplate = savedTemplate
                                print("📝 Loaded template from note: \(savedTemplate.type.rawValue)")
                            } else {
                                noteTemplate = .none
                                print("📝 No template found in note, using default")
                            }
                            
                            // Load from UserDefaults as fallback
                            loadNoteTemplateIfWanted()
                            
                            // Force template refresh after a short delay to ensure views are ready
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("RefreshTemplate"),
                                    object: nil
                                )
                                
                                // Mark initial load complete
                                isInitialLoad = false
                            }
                            
                            // Register for drawing state notifications
                            registerForDrawingNotifications()
                            
                            // Register for coordinator ready notification
                            NotificationCenter.default.addObserver(
                                forName: NSNotification.Name("CoordinatorReady"),
                                object: nil,
                                queue: .main
                            ) { notification in
                                if let coordinator = notification.object as? MultiPageUnifiedScrollView.Coordinator {
                                    self.scrollViewCoordinator = coordinator
                                }
                            }
                            
                            // Listen for page selection changes
                            NotificationCenter.default.addObserver(
                                forName: NSNotification.Name("PageSelected"),
                                object: nil,
                                queue: .main
                            ) { notification in
                                if let pageIndex = notification.object as? Int {
                                    self.selectedPageIndex = pageIndex
                                }
                            }
                            
                            // Listen for toggle sidebar notifications
                            NotificationCenter.default.addObserver(
                                forName: NSNotification.Name("ToggleSidebar"),
                                object: nil,
                                queue: .main
                            ) { notification in
                                withAnimation {
                                    self.isPageNavigatorVisible.toggle()
                                }
                            }
                        }
                        .onChange(of: selectedPageIndex) { _, newIndex in
                            // Notify MultiPageUnifiedScrollView to scroll to the selected page
                            // Only trigger scrolling if the selection was made by clicking a thumbnail
                            if !isInitialLoad && isPageSelectionActive {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ScrollToPage"),
                                    object: newIndex
                                )
                            }
                        }
                        .onChange(of: noteTemplate) { oldValue, newValue in
                            print("🔍 NoteDetailView - Template changed from \(oldValue.type.rawValue) to \(newValue.type.rawValue)")
                            print("🔍 Source: Internal state change")
                            
                            // Update the note template in the store
                            if !isInitialLoad, let currentNote = note {
                                let updatedNote = currentNote.copyWith(noteTemplate: newValue)
                                eventStore.dispatch(NoteAction.updateNote(
                                    updatedNote,
                                    subjectID: subjectID
                                ))
                                
                                // Force a refresh of the template
                                DispatchQueue.main.async {
                                    print("🔍 Posting ForceTemplateRefresh notification after template change")
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("ForceTemplateRefresh"),
                                        object: nil
                                    )
                                }
                            } else {
                                print("🔍 Skipping template update during initial load")
                            }
                        }
                        .onEvent(TemplateEvents.TemplateChanged.self) { event in
                            // This ensures template changes are synchronized across the app
                            print("🔄 NoteDetailView received TemplateChanged event, updating template from \(noteTemplate.type.rawValue) to \(event.template.type.rawValue)")
                            print("🔄 Source: External event")
                            
                            if noteTemplate.type != event.template.type || 
                               noteTemplate.colorHex != event.template.colorHex ||
                               noteTemplate.spacing != event.template.spacing ||
                               noteTemplate.lineWidth != event.template.lineWidth {
                                
                                print("🔄 Template properties changed, updating...")
                                
                                // Update the local template with the received one
                                noteTemplate = event.template
                                print("🔄 Set local noteTemplate to \(event.template.type.rawValue)")
                                
                                // Update the note model via EventStore
                                if let currentNote = note {
                                    let updatedNote = currentNote.copyWith(noteTemplate: event.template)
                                    eventStore.dispatch(NoteAction.updateNote(
                                        updatedNote,
                                        subjectID: subjectID
                                    ))
                                    print("🔄 Dispatched NoteAction.updateNote with template \(event.template.type.rawValue)")
                                    
                                    // Also update the DataManager for compatibility during transition
                                    dataManager.updateNoteTemplateAndSaveImmediately(
                                        in: subjectID,
                                        noteID: currentNote.id,
                                        template: event.template
                                    )
                                }
                            } else {
                                print("🔄 No template properties changed, skipping update")
                            }
                        }
                        .actionSheet(isPresented: $showExportOptions) {
                            ActionSheet(
                                title: Text("Export Note"),
                                message: Text("Choose export format"),
                                buttons: [
                                    .default(Text("PDF")) {
                                        exportToPDF()
                                    },
                                    .default(Text("Image")) {
                                        print("Image export requested (not implemented yet)")
                                    },
                                    .cancel()
                                ]
                            )
                        }
                        .sheet(isPresented: $showingTemplateSettings) {
                            // Present the template settings sheet
                            TemplateSettingsView(template: $noteTemplate)
                        }
                        .onDisappear {
                            // Invalidate the thumbnail when leaving the note editor
                            if let currentNote = note {
                                ThumbnailGenerator.invalidateThumbnail(for: currentNote.id)
                            }
                            
                            // Clean up drawing notifications
                            NotificationCenter.default.removeObserver(self)
                            
                            // Always save when view disappears by updating lastModified
                            if let currentNote = note {
                                let updatedNote = currentNote.copyWith(
                                    title: localTitle,
                                    lastModified: Date(),
                                    noteTemplate: noteTemplate
                                )
                                eventStore.dispatch(NoteAction.updateNote(
                                    updatedNote,
                                    subjectID: subjectID
                                ))
                            }
                        }
                        .overlay(
                            ZStack {
                                CustomToolbar(
                                    coordinator: scrollViewCoordinator,
                                    selectedTool: $selectedTool,
                                    selectedColor: $selectedColor,
                                    lineWidth: $lineWidth
                                )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                    
                    // Add debug overlay in the corner
                    DebugOverlayView()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Drawing Notifications
    
    private func registerForDrawingNotifications() {
        NotificationCenter.default.removeObserver(self)
        
        // Listen for drawing start/end to manage template refreshes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DrawingDidComplete"),
            object: nil,
            queue: .main
        ) { _ in
            print("📝 DrawingDidComplete notification received")
            self.isDrawingActive = false
            
            // Force a template refresh after drawing completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !self.isDrawingActive {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshTemplate"),
                        object: nil
                    )
                }
            }
        }
    }
    
    // MARK: - Migration
    private func migrateIfNeeded() {
        guard let currentNote = note else { return }
        
        // If this note has no pages but DOES have old single-drawing data,
        // convert it into a single Page. Then clear drawingData.
        if currentNote.pages.isEmpty && !currentNote.drawingData.isEmpty {
            print("📝 Migrating old single-drawing note -> multi-page note")
            let newPage = Page(
                drawingData: currentNote.drawingData,
                template: nil,
                pageNumber: 1
            )
            
            let updatedNote = currentNote.copyWith(
                drawingData: Data(), pages: [newPage]
            )
            
            eventStore.dispatch(NoteAction.updateNote(
                updatedNote,
                subjectID: subjectID
            ))
        }
    }
    
    // MARK: - Template Loading
    private func loadNoteTemplateIfWanted() {
        guard let currentNote = note else { return }
        
        // First check if the note has a saved template
        if let savedTemplate = currentNote.noteTemplate {
            noteTemplate = savedTemplate
            return
        }
        
        // Then check UserDefaults as a fallback
        if let data = UserDefaults.standard.data(forKey: "noteTemplate.\(currentNote.id.uuidString)") {
            if let loadedTemplate = try? JSONDecoder().decode(CanvasTemplate.self, from: data) {
                noteTemplate = loadedTemplate
            }
        }
    }
    
    // MARK: - Save
    private func saveChanges() {
        guard let currentNote = note else { return }
        
        let updatedNote = currentNote.copyWith(
            title: localTitle,
            lastModified: Date(),
            noteTemplate: noteTemplate
        )
        
        // Dispatch the update through EventStore
        eventStore.dispatch(NoteAction.updateNote(
            updatedNote,
            subjectID: subjectID
        ))
        
        // Also store in UserDefaults as a backup
        let data = try? JSONEncoder().encode(noteTemplate)
        UserDefaults.standard.set(data, forKey: "noteTemplate.\(currentNote.id.uuidString)")
        
        print("📝 Note changes saved (multi-page with template).")
    }
    
    // MARK: - PDF Export
    private func exportToPDF() {
        guard let currentNote = note else {
            print("⚠️ Cannot export PDF: No valid note")
            return
        }
        
        print("📝 PDF Export requested for multi-page note with template (placeholder).")
        // You can use combineAllPagesIntoOneDrawing() or handle multi-page PDF.
    }
    
    private func combineAllPagesIntoOneDrawing() -> PKDrawing {
        guard let currentNote = note else { return PKDrawing() }
        
        var combined = PKDrawing()
        
        for (index, page) in currentNote.pages.enumerated() {
            let offsetY = CGFloat(index) * 792 // standard letter
            let pageDrawing = PKDrawing.fromData(page.drawingData)
            
            let translatedStrokes = pageDrawing.strokes.map { stroke -> PKStroke in
                transformStroke(stroke, offsetY: offsetY)
            }
            combined = PKDrawing(strokes: combined.strokes + translatedStrokes)
        }
        
        return combined
    }
    
    private func transformStroke(_ stroke: PKStroke, offsetY: CGFloat) -> PKStroke {
        // If iOS 15+ only, you can do stroke.path.transform(...)
        let newControlPoints = stroke.path.map { point -> PKStrokePoint in
            let translatedLocation = point.location.applying(CGAffineTransform(translationX: 0, y: offsetY))
            return PKStrokePoint(
                location: translatedLocation,
                timeOffset: point.timeOffset,
                size: point.size,
                opacity: point.opacity,
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }
        let newPath = PKStrokePath(controlPoints: newControlPoints, creationDate: stroke.path.creationDate)
        return PKStroke(ink: stroke.ink, path: newPath, transform: .identity, mask: stroke.mask)
    }
}
