//
//  NoteListView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  This file provides a list view of notes for a selected subject.
//  Key responsibilities:
//    - Displaying notes in a vertical list
//    - Handling note creation with the + button
//    - Managing note deletion
//    - Navigation to the note detail view for a selected note
//
//  This provides an alternative to NotePreviewsGrid when a simple
//  list view is preferred over thumbnails.
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
                NavigationLink(destination: NoteDetailView(noteIndex: index, subjectID: subject.id)) {
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
