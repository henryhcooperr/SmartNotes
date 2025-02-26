//
//  NoteView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI
import PencilKit

struct NoteView: View {
    @Binding var note: Note      // The note we are editing
    @State private var pkDrawing = PKDrawing()  // The live PKDrawing

    var body: some View {
        VStack {
            TextField("Enter note title", text: $note.title)
                .font(.title)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Our canvas area
            CanvasView(drawing: $pkDrawing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // Convert stored Data to PKDrawing on appear
                    pkDrawing = PKDrawing.fromData(note.drawingData)
                }
                .onChange(of: pkDrawing) { newValue in
                    // Convert PKDrawing back to Data whenever it changes
                    note.drawingData = newValue.toData()
                }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
