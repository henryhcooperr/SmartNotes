//
//  NotePreviewCard.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//  Updated to fix navigation issues
//

import SwiftUI
import PencilKit

struct NotePreviewCard: View {
    @Binding var note: Note
    @Binding var subject: Subject
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink {
            NoteDetailView(note: $note, subjectID: subject.id)
        } label: {
            cardContents
        }
        .buttonStyle(.plain) // Make the link look like a card
    }
    
    private var cardContents: some View {
        // Compute the thumbnail
        let thumbnailImage = noteImage
        let hasDrawing = hasDrawingContent
        let pageCount = max(1, note.pages.count)
        
        return VStack(alignment: .leading, spacing: 0) {
            // Top section with thumbnail or placeholder
            ZStack(alignment: .topTrailing) {
                if thumbnailImage.size.width > 0 {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 110)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    // Fallback placeholder
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 110)
                }
                
                // Page count indicator if multiple pages
                if pageCount > 1 {
                    Text("\(pageCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .foregroundColor(subject.color)
                        .cornerRadius(6)
                        .padding(8)
                }
            }
            
            // Bottom info section
            VStack(alignment: .leading, spacing: 6) {
                // Title with icon
                HStack(spacing: 6) {
                    // Icon based on content type
                    Image(systemName: hasDrawing ? "pencil.tip" : "doc.text")
                        .foregroundColor(hasDrawing ? .purple : .blue)
                        .font(.system(size: 14))
                    
                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                .padding(.top, 8)
                
                // Date info
                Text(note.dateCreated, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Subject indicator
                Text(subject.name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(.white)
                    .background(subject.color)
                    .cornerRadius(6)
            }
            .padding()
        }
        .background(Color(colorScheme == .dark ? .systemGray6 : .systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    // Get thumbnail image for the note - handling both legacy and multi-page formats
    private var noteImage: UIImage {
        // Check for main drawing data first (legacy format)
        if !note.drawingData.isEmpty {
            let loadedDrawing = PKDrawing.fromData(note.drawingData)
            if !loadedDrawing.strokes.isEmpty {
                let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
                let scale: CGFloat = 0.15
                
                return loadedDrawing.image(from: pageRect, scale: scale)
            }
        }
        
        // Check for multi-page drawing data
        if !note.pages.isEmpty, let firstPage = note.pages.first,
           !firstPage.drawingData.isEmpty {
            let loadedDrawing = PKDrawing.fromData(firstPage.drawingData)
            if !loadedDrawing.strokes.isEmpty {
                let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
                let scale: CGFloat = 0.15
                
                return loadedDrawing.image(from: pageRect, scale: scale)
            }
        }
        
        return UIImage()
    }
    
    // Check if note has any drawing content - handling both formats
    private var hasDrawingContent: Bool {
        // Check legacy drawing data
        if !note.drawingData.isEmpty {
            let drawing = PKDrawing.fromData(note.drawingData)
            if !drawing.strokes.isEmpty {
                return true
            }
        }
        
        // Check pages
        for page in note.pages {
            if !page.drawingData.isEmpty {
                let drawing = PKDrawing.fromData(page.drawingData)
                if !drawing.strokes.isEmpty {
                    return true
                }
            }
        }
        
        return false
    }
}
