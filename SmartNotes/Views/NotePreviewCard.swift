//
//  NotePreviewCard.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  This file defines a reusable card view for note previews.
//  Key responsibilities:
//    - Displaying a thumbnail of the note content
//    - Showing the note title and creation date
//    - Displaying the subject indicator with color
//    - Handling navigation to the note detail view
//
//  This component is used by NotePreviewsGrid to display
//  individual notes in the grid layout.
//

import SwiftUI
import PencilKit

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
        // Compute the thumbnail first
        let thumbnailImage = forcedFirstPageThumbnail
        
        // Print in a side-effect expression (rather than inline in the View builder)
        let _ = print("Thumbnail size = \(thumbnailImage.size)")
        
        return VStack(alignment: .leading) {
            if thumbnailImage.size.width > 0 && thumbnailImage.size.height > 0 {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .background(Color.white)
                    .overlay(
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else {
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

    // MARK: - Computed Property: forcedFirstPageThumbnail
    private var forcedFirstPageThumbnail: UIImage {
        // 1. If there's no drawing data, return an empty UIImage
        guard !note.drawingData.isEmpty else { return UIImage() }
        
        // 2. Attempt to load a PKDrawing
        guard let loadedDrawing = try? PKDrawing(data: note.drawingData),
              !loadedDrawing.strokes.isEmpty else {
            return UIImage()
        }
        
        // 3. Force the "first page" rectangle (8.5" x 11" at 72DPI)
        let firstPageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        // 4. Figure out an appropriate scale
        let scale: CGFloat = 0.15 // Adjust as desired to fit your card height
        
        // 5. Render a UIImage from that forced rectangle
        return loadedDrawing.image(from: firstPageRect, scale: scale)
    }
}
