//
//  NoteDetailView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//  Updated on 3/5/25 to use MultiPageUnifiedScrollView
//

import SwiftUI
import PencilKit

struct NoteDetailView: View {
    @Binding var note: Note
    @EnvironmentObject var dataManager: DataManager
    let subjectID: UUID
    
    // Local copy of the note title for editing
    @State private var localTitle: String
    
    // Track whether we've just loaded the note
    @State private var isInitialLoad = true
    
    // Whether to show the export ActionSheet
    @State private var showExportOptions = false
    
    @Environment(\.presentationMode) private var presentationMode
    
    // MARK: - Init
    init(note: Binding<Note>, subjectID: UUID) {
        self._note = note
        self.subjectID = subjectID
        // Start localTitle with whatever is in the note
        self._localTitle = State(initialValue: note.wrappedValue.title)
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Title area
            TextField("Note Title", text: $localTitle)
                .font(.title)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: localTitle) { oldValue, newValue in
                    // Only update the note model after the initial load
                    if !isInitialLoad {
                        note.title = newValue
                        saveChanges()
                    }
                }
                .padding(.horizontal)
            
            // Divider between title and canvas
            Divider()
                .padding(.horizontal)
            
            // ---- Here's the key: show the Unified Scroll of multiple pages ----
            MultiPageUnifiedScrollView(pages: $note.pages)
                .onAppear {
                    migrateIfNeeded()  // Convert old single-drawing data to pages, if needed
                    // Mark initial load complete after a short delay
                    DispatchQueue.main.async {
                        isInitialLoad = false
                    }
                }
                .onChange(of: note.pages) { _ in
                    // Save changes to DataManager whenever pages array changes
                    if !isInitialLoad {
                        saveChanges()
                    }
                }
        }
        // Navigation bar
        .navigationTitle(localTitle.isEmpty ? "Untitled" : localTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // "Done" button to dismiss
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    saveChanges()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            // Template settings button (optional)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowTemplateSettings"),
                        object: nil
                    )
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
                        // Not implemented
                        print("Image export requested")
                    },
                    .cancel()
                ]
            )
        }
        .onDisappear {
            // Always save when view disappears
            saveChanges()
        }
    }
    
    // MARK: - MIGRATION
    private func migrateIfNeeded() {
        // If this note has no pages but DOES have old single-drawing data,
        // convert it into a single Page. Then clear drawingData to avoid re-migration.
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
    
    // MARK: - SAVE
    private func saveChanges() {
        note.title = localTitle
        note.lastModified = Date()
        dataManager.updateNote(in: subjectID, note: note)
        print("📝 Note changes saved (multi-page)")
    }
    
    // MARK: - PDF EXPORT
    private func exportToPDF() {
        // Currently a placeholder. You can adapt your PDFExporter
        // to handle multiple pages. For example, combineAllPagesIntoOneDrawing()
        // or generate a multi-page PDF document.
        print("📝 PDF Export requested for multi-page note.")
    }
    
    // Example if you want to combine all pages into one big PKDrawing
    private func combineAllPagesIntoOneDrawing() -> PKDrawing {
        var combined = PKDrawing()
        
        for (index, page) in note.pages.enumerated() {
            let offsetY = CGFloat(index) * 792 // for standard letter
            let pageDrawing = PKDrawing.fromData(page.drawingData)
            
            let translatedStrokes = pageDrawing.strokes.map { stroke -> PKStroke in
                transformStroke(stroke, offsetY: offsetY)
            }
            combined = PKDrawing(strokes: combined.strokes + translatedStrokes)
        }
        
        return combined
    }
    
    private func transformStroke(_ stroke: PKStroke, offsetY: CGFloat) -> PKStroke {
        // If only iOS 15+ is supported, you can do:
        // stroke.path.transform(using: CGAffineTransform(translationX: 0, y: offsetY))
        // else do manual path transform:
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
        return PKStroke(
            ink: stroke.ink,
            path: newPath,
            transform: .identity,
            mask: stroke.mask
        )
    }
}
