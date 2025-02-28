//
//  NoteDetailView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  Updated to use multi‐page approach on 3/1/25.
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
            
            // -- Replace TemplateCanvasView with MultiPageCanvasView --
            MultiPageCanvasView(pages: $note.pages)
                .onAppear {
                    // Migrate older single-drawing data (if any) to multi-page
                    migrateIfNeeded()
                    
                    // Mark initial load complete so future changes get saved
                    DispatchQueue.main.async {
                        isInitialLoad = false
                    }
                }
                .onChange(of: note.pages) { _ in
                    // Whenever pages change (new page added, etc.), save
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
            
            // Template settings button (if you still want a global template)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Show template settings for the note-level template
                    // (Or skip if each page has its own template)
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
                        print("Image export requested (not implemented)")
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
    
    // MARK: - Migration for Old Notes
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
    
    // MARK: - Save Changes
    private func saveChanges() {
        note.title = localTitle
        note.lastModified = Date()
        dataManager.updateNote(in: subjectID, note: note)
        print("📝 Note changes saved")
    }
    
    // MARK: - PDF Export
    private func exportToPDF() {
        // Right now, your PDFExporter is built around a single PKDrawing.
        // You can adapt it to handle multiple pages by combining them or
        // generating a multi-page PDF. For now, just show a placeholder.
        
        print("📝 PDF Export requested for multi-page note")
        
        // Example: If you want a quick hack that merges all pages into one
        // PKDrawing, you'd do something like:
        // let mergedDrawing = combineAllPagesIntoOneDrawing()
        // Then pass that to PDFExporter.
        
        // Or create a multi-page PDF with each page drawn in its own rect.
        // For now, just log a message or show an alert.
    }
    
    // Optional if you want to merge pages for PDF
    private func combineAllPagesIntoOneDrawing() -> PKDrawing {
        var combined = PKDrawing()
        
        for (index, page) in note.pages.enumerated() {
            let offsetY = CGFloat(index) * 792 // US Letter page height
            let pageDrawing = PKDrawing.fromData(page.drawingData)
            
            // Translate each stroke by offsetY and append to `combined`.
            let translatedStrokes = pageDrawing.strokes.map { stroke -> PKStroke in
                return transformStroke(stroke, offsetY: offsetY)
            }
            
            combined = PKDrawing(strokes: combined.strokes + translatedStrokes)
        }
        
        return combined
    }

    // MARK: - Manual Stroke Transform
    private func transformStroke(_ stroke: PKStroke, offsetY: CGFloat) -> PKStroke {
        // If you only support iOS 15+, you could do:
        // if #available(iOS 15.0, *) {
        //     let newPath = stroke.path.transform(using: CGAffineTransform(translationX: 0, y: offsetY))
        //     return PKStroke(ink: stroke.ink, path: newPath, transform: .identity, mask: stroke.mask)
        // }
        // else fallback below:
        
        // Fallback for iOS < 15: manually translate each control point
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
        
        // Recreate the PKStrokePath with the new control points
        let newPath = PKStrokePath(
            controlPoints: newControlPoints,
            creationDate: stroke.path.creationDate
        )
        
        // Return a stroke with the translated path
        return PKStroke(
            ink: stroke.ink,
            path: newPath,
            transform: .identity,
            mask: stroke.mask
        )
    }
}
