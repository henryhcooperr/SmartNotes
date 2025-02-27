//
//  NoteDetailView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI
import PencilKit

struct NoteDetailView: View {
    @Binding var note: Note
    @EnvironmentObject var dataManager: DataManager
    let subjectID: UUID
    
    @State private var pkDrawing = PKDrawing()
    @State private var localTitle: String
    @State private var showExportOptions = false
    @Environment(\.presentationMode) private var presentationMode
    
    // Add flags to control initialization and updates
    @State private var isInitialLoad = true
    
    // Initialize the local title with the note's title
    init(note: Binding<Note>, subjectID: UUID) {
        self._note = note
        self.subjectID = subjectID
        self._localTitle = State(initialValue: note.wrappedValue.title)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title area
            TextField("Note Title", text: $localTitle)
                .font(.title)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: localTitle) { newValue in
                    // Only update during normal operation, not initial load
                    if !isInitialLoad {
                        note.title = newValue
                    }
                }
                .padding(.horizontal)
            
            // Divider between title and canvas
            Divider()
                .padding(.horizontal)
            
            // Use the TemplateCanvasView with our drawing binding
            TemplateCanvasView(drawing: $pkDrawing)
                .onAppear {
                    // Load drawing data when view appears - with safety delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        loadDrawingData()
                    }
                }
                .onChange(of: pkDrawing) { newValue in
                    // Only save drawing changes after initialization
                    if !isInitialLoad {
                        saveDrawingData(newValue)
                    }
                }
        }
        .navigationTitle(localTitle.isEmpty ? "Untitled" : localTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    saveChanges()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Show template settings
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowTemplateSettings"),
                        object: nil
                    )
                }) {
                    Image(systemName: "ellipsis")
                }
            }
            
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
                        // Image export functionality would go here
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
    
    // Safely load drawing data
    // Update the loadDrawingData method to handle errors gracefully:
    private func loadDrawingData() {
        print("📝 Loading drawing data...")
        
        if note.drawingData.isEmpty {
            print("📝 Note has no drawing data, using empty drawing")
            pkDrawing = PKDrawing()
        } else {
            do {
                // Try to load the drawing from data
                pkDrawing = try PKDrawing(data: note.drawingData)
                print("📝 Successfully loaded drawing data: \(note.drawingData.count) bytes")
            } catch {
                print("📝 Error loading drawing data: \(error.localizedDescription)")
                pkDrawing = PKDrawing() // Fall back to empty drawing
            }
        }
        
        // Mark initialization as complete after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isInitialLoad = false
            print("📝 Note ready for editing")
        }
    }
    
    // Safely save drawing data to the note
    private func saveDrawingData(_ drawing: PKDrawing) {
        do {
            note.drawingData = try drawing.dataRepresentation()
            print("📝 Saved drawing data: \(note.drawingData.count) bytes")
        } catch {
            print("📝 Error saving drawing data: \(error.localizedDescription)")
        }
    }
    
    private func saveChanges() {
        print("📝 Saving note changes")
        note.title = localTitle
        saveDrawingData(pkDrawing)
        note.lastModified = Date()
        
        // Assuming you have access to DataManager and subjectID
        dataManager.updateNote(in: subjectID, note: note)
    }
    
    private func exportToPDF() {
        // Create a temporary template for getting page rects
        let rects = calculatePageRects()
        
        // Export to PDF
        if let pdfURL = PDFExporter.exportNoteToPDF(note: note, pageRects: rects) {
            // Find the view controller to present from using the modern scene API
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let viewController = window.rootViewController {
                PDFExporter.presentPDFForSharing(url: pdfURL, from: viewController)
            }
        }
    }
    
    // Helper method to calculate page rects for PDF export
    private func calculatePageRects() -> [CGRect] {
        // Determine how many pages based on drawing bounds
        let pageHeight = 792.0 // Letter size height
        let pageWidth = 612.0 // Letter size width
        
        // Calculate drawing bounds
        let drawingBounds = pkDrawing.bounds
        
        // Calculate how many pages needed
        let pagesNeeded = max(
            2, // Minimum 2 pages
            Int(ceil(drawingBounds.maxY / pageHeight)) + 1 // +1 for safety
        )
        
        // Create page rects
        var rects = [CGRect]()
        for i in 0..<pagesNeeded {
            let pageRect = CGRect(
                x: 0,
                y: CGFloat(i) * pageHeight,
                width: pageWidth,
                height: pageHeight
            )
            rects.append(pageRect)
        }
        
        return rects
    }
}
