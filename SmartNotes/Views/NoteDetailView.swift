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
    @State private var pkDrawing = PKDrawing()
    @Environment(\.dismiss) private var dismiss
    @State private var localTitle: String  // Local state to track title changes

    // Initialize the local title with the note's title
    init(note: Binding<Note>) {
        self._note = note
        self._localTitle = State(initialValue: note.wrappedValue.title)
    }

    var body: some View {
        VStack {
            TextField("Note Title", text: $localTitle)
                .font(.title)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: localTitle) { newValue in
                    // Immediately sync title changes to the note binding
                    note.title = newValue
                }
            
            // Use the CanvasView from CanvasView.swift
            CanvasView(drawing: $pkDrawing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // Load drawing data when view appears
                    if !note.drawingData.isEmpty {
                        pkDrawing = PKDrawing.fromData(note.drawingData)
                    } else {
                        // Initialize empty drawing if data is empty
                        pkDrawing = PKDrawing()
                    }
                }
                .onChange(of: pkDrawing) { newValue in
                    // Save drawing data when it changes
                    note.drawingData = newValue.toData()
                    print("Drawing data updated: \(note.drawingData.count) bytes")
                }
        }
        .navigationTitle(localTitle.isEmpty ? "Untitled" : localTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    // Ensure the latest changes are saved
                    note.title = localTitle
                    note.drawingData = pkDrawing.toData()
                    dismiss()
                }
            }
        }
    }
}
