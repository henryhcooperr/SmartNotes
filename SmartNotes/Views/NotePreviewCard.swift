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
            NoteDetailView(note: $note, subjectID: subject.id)
        }) {
            cardContents
        }
        .buttonStyle(.plain) // Make the link look like a card
    }
    
    private var cardContents: some View {
        VStack(alignment: .leading) {
            let thumbnailImage = ThumbnailGenerator.generateThumbnail(from: note)
            
            // Debug: Print image size and check if it's valid
            if thumbnailImage.size.width > 0 && thumbnailImage.size.height > 0 {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFit() // Changed from .fill to .fit
                    .frame(height: 100)
                    .background(Color.white)
                    .overlay(
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else {
                // Fallback placeholder if thumbnail generation fails
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 100)
            }
            
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.dateCreated, format: .dateTime.month().day().year())
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
