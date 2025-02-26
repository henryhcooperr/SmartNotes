//
//  NoteListView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI
import PencilKit

struct NotesListView: View {
    // Instead of storing [Note] directly, we store a binding to a Subject
    @Binding var subject: Subject
    
    // Explicitly passing a Binding<Subject> to avoid ambiguity
    init(subject: Binding<Subject>) {
        self._subject = subject
    }

    var body: some View {
        List {
            // List all notes inside this subject
            ForEach($subject.notes.indices, id: \.self) { index in
                let noteBinding = $subject.notes[index]
                NavigationLink(destination: NoteDetailView(note: noteBinding)) {
                    Text(subject.notes[index].title.isEmpty ? "Untitled Note" : subject.notes[index].title)
                }
            }
            .onDelete(perform: deleteNotes)
        }
        .navigationTitle(subject.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: createNewNote) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Functions

    private func createNewNote() {
        let newNote = Note(title: "", drawingData: PKDrawing().toData())
        subject.notes.append(newNote)
    }

    private func deleteNotes(at offsets: IndexSet) {
        subject.notes.remove(atOffsets: offsets)
    }
}
