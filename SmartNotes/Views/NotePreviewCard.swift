//
//  NotePreviewCard.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI

struct NotePreviewCard: View {
    @Binding var note: Note
    @Binding var subject: Subject
    
    var body: some View {
        NavigationLink(destination: {
            // Destination is a detail note view
            NoteDetailView(note: $note)
        }) {
            cardContents
        }
        .buttonStyle(.plain) // Make the link look like a card
    }
    
    private var cardContents: some View {
        VStack(alignment: .leading) {
            // Placeholder for the note "thumbnail"
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 100)
            
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.headline)
                .lineLimit(1)
            
            // Format the date
            Text(note.dateCreated, format: .dateTime.month().day().year())
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Subject tag
            Text(subject.name)
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .foregroundColor(.white)
                .background(subject.color)
                .cornerRadius(6)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}
