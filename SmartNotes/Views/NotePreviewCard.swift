//
//  NotePreviewCard.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//  Updated to fix navigation issues
//  Updated to use EventStore for state management
//

import SwiftUI
import PencilKit

struct NotePreviewCard: View {
    // Replace Binding parameters with direct values and EventStore
    @EnvironmentObject var eventStore: EventStore
    @Environment(\.colorScheme) private var colorScheme
    
    // Use IDs instead of Binding to reference data
    let noteID: UUID
    let subjectID: UUID
    
    // Computed properties to access data from EventStore
    private var subject: Subject? {
        eventStore.state.contentState.subjects.first(where: { $0.id == subjectID })
    }
    
    private var note: Note? {
        subject?.notes.first(where: { $0.id == noteID })
    }
    
    var body: some View {
        // Find the note index in the subject's notes array
        let noteIndex = subject?.notes.firstIndex(where: { $0.id == noteID }) ?? 0
        
        return NavigationLink {
            NoteDetailView(noteIndex: noteIndex, subjectID: subjectID)
        } label: {
            cardContents
        }
        .buttonStyle(.plain) // Make the link look like a card
    }
    
    private var cardContents: some View {
        // Guard against missing data
        guard let currentNote = note, let currentSubject = subject else {
            return AnyView(
                Text("Note not found")
                    .foregroundColor(.secondary)
                    .padding()
            )
        }
        
        // Compute the thumbnail
        let thumbnailImage = noteImage
        let hasDrawing = hasDrawingContent
        let pageCount = max(1, currentNote.pages.count)
        
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                // Top section with thumbnail or placeholder
                ZStack(alignment: .topTrailing) {
                    if thumbnailImage.size.width > 0 {
                        // IMPROVED DISPLAY: Better scaling and shadow
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 110)
                            .clipped()
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                            )
                            // Add subtle inner shadow
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.black.opacity(0.03), lineWidth: 1)
                                    .blur(radius: 1)
                                    .offset(y: 1)
                                    .mask(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(LinearGradient(
                                                gradient: Gradient(colors: [.black, .clear]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ))
                                    )
                            )
                    } else {
                        // Improved placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 110)
                            .overlay(
                                VStack {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("Empty")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            )
                    }
                    
                    // Page count indicator if multiple pages
                    if pageCount > 1 {
                        Text("\(pageCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                            )
                            .foregroundColor(currentSubject.color)
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
                        
                        Text(currentNote.title.isEmpty ? "Untitled Note" : currentNote.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .padding(.top, 8)
                    
                    // Date info
                    Text(currentNote.dateCreated, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Subject indicator
                    Text(currentSubject.name)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundColor(.white)
                        .background(currentSubject.color)
                        .cornerRadius(6)
                }
                .padding()
            }
            .background(Color(colorScheme == .dark ? .systemGray6 : .systemBackground))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }
    
    // Get thumbnail image for the note - handling both legacy and multi-page formats
    private var noteImage: UIImage {
        guard let currentNote = note else {
            return UIImage()
        }
        
        return ThumbnailGenerator.generateThumbnail(
            from: currentNote,
            size: CGSize(width: 300, height: 200),
            highQuality: true
        )
    }
    
    // Check if note has any drawing content - handling both formats
    private var hasDrawingContent: Bool {
        guard let currentNote = note else {
            return false
        }
        
        // Check legacy drawing data
        if !currentNote.drawingData.isEmpty {
            let drawing = PKDrawing.fromData(currentNote.drawingData)
            if !drawing.strokes.isEmpty {
                return true
            }
        }
        
        // Check pages
        for page in currentNote.pages {
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
