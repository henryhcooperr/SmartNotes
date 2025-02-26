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
            
            // Use the PagedCanvasView with our drawing binding
            PagedCanvasView(drawing: $pkDrawing)
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
            isInitialLoad = false
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
        // Get page rects from a PagedCanvasView instance
        let pageRects = PagedCanvasView(drawing: $pkDrawing).getPageRects()
        
        // Export to PDF
        if let pdfURL = PDFExporter.exportNoteToPDF(note: note, pageRects: pageRects) {
            // Find the view controller to present from using the modern scene API
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let viewController = window.rootViewController {
                PDFExporter.presentPDFForSharing(url: pdfURL, from: viewController)
            }
        }
    }
}
