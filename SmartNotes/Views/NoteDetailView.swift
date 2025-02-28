//
//  NoteDetailView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//  Updated on 3/6/25 to support a single, note-wide template and unified multi-page
//

import SwiftUI
import PencilKit

struct NoteDetailView: View {
    @Binding var note: Note
    @EnvironmentObject var dataManager: DataManager
    let subjectID: UUID
    
    // Local copy of the note title
    @State private var localTitle: String
    
    // Track whether we've just loaded the note
    @State private var isInitialLoad = true
    
    // Whether to show the export ActionSheet
    @State private var showExportOptions = false
    
    // Keep a single note-level template
    @State private var noteTemplate: CanvasTemplate = .none
    
    // Control sheet presentation for TemplateSettingsView
    @State private var showingTemplateSettings = false
    
    @Environment(\.presentationMode) private var presentationMode
    
    init(note: Binding<Note>, subjectID: UUID) {
        self._note = note
        self.subjectID = subjectID
        // Start localTitle with whatever is in the note
        self._localTitle = State(initialValue: note.wrappedValue.title)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title area
            TextField("Note Title", text: $localTitle)
                .font(.title)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: localTitle) { oldValue, newValue in
                    // Only update the note model after initial load
                    if !isInitialLoad {
                        note.title = newValue
                        saveChanges()
                    }
                }
                .padding(.horizontal)
            
            Divider().padding(.horizontal)
            
            // Unified multi-page scroll
            MultiPageUnifiedScrollView(pages: $note.pages, template: $noteTemplate)
                .onAppear {
                    // Migrate older single-drawing data to pages if needed
                    migrateIfNeeded()
                    
                    // Load a saved template if you want a persistent note-level template:
                    loadNoteTemplateIfWanted()
                    
                    // Mark initial load complete
                    DispatchQueue.main.async {
                        isInitialLoad = false
                    }
                }
                .onChange(of: note.pages) { _ in
                    // Save if pages change
                    if !isInitialLoad {
                        saveChanges()
                    }
                }
                .onChange(of: noteTemplate) { _ in
                    // Reapply template changes
                    if !isInitialLoad {
                        saveChanges()
                    }
                }
        }
        // Navigation
        .navigationTitle(localTitle.isEmpty ? "Untitled" : localTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Done button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    saveChanges()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            // Template settings button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingTemplateSettings = true
                }) {
                    Image(systemName: "ellipsis")
                }
            }
            
            // Export button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showExportOptions = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
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
            // Always save when view disappears
            saveChanges()
        }
    }
    
    // MARK: - Migration
    private func migrateIfNeeded() {
        // If this note has no pages but DOES have old single-drawing data,
        // convert it into a single Page. Then clear drawingData.
        if note.pages.isEmpty && !note.drawingData.isEmpty {
            print("📝 Migrating old single-drawing note -> multi-page note")
            let newPage = Page(
                drawingData: note.drawingData,
                template: nil,
                pageNumber: 1
            )
            note.pages = [newPage]
            note.drawingData = Data()
        }
    }
    
    // (Optional) If you want to load a saved note-level template from the note model or from UserDefaults,
    // implement something like loadNoteTemplateIfWanted(). Otherwise you can skip it.
    private func loadNoteTemplateIfWanted() {
        // Example: if your Note has a `noteTemplate` property. Or from UserDefaults:
        // if let data = UserDefaults.standard.data(forKey: "noteTemplate.\(note.id.uuidString)") {
        //     if let loadedTemplate = try? JSONDecoder().decode(CanvasTemplate.self, from: data) {
        //         noteTemplate = loadedTemplate
        //     }
        // }
    }
    
    // MARK: - Save
    private func saveChanges() {
        note.title = localTitle
        note.lastModified = Date()
        
        // You might also want to store `noteTemplate` if you want it persistent:
        // let data = try? JSONEncoder().encode(noteTemplate)
        // UserDefaults.standard.set(data, forKey: "noteTemplate.\(note.id.uuidString)")
        
        dataManager.updateNote(in: subjectID, note: note)
        print("📝 Note changes saved (multi-page with template).")
    }
    
    // MARK: - PDF Export
    private func exportToPDF() {
        print("📝 PDF Export requested for multi-page note with template (placeholder).")
        // You can combineAllPagesIntoOneDrawing() or handle multi-page PDF.
    }
    
    private func combineAllPagesIntoOneDrawing() -> PKDrawing {
        var combined = PKDrawing()
        
        for (index, page) in note.pages.enumerated() {
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
