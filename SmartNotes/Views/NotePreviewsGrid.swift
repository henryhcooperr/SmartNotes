//
//  NotePreviewsGrid.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  This file provides a grid layout of note thumbnails for a selected subject.
//  Key responsibilities:
//    - Displaying notes as a grid of preview cards
//    - Generating thumbnails from note drawing data
//    - Handling navigation to the note detail view
//    - Creating new notes
//
//  This view is shown in the detail area of SubjectsSplitView when
//  a subject is selected.
//

import SwiftUI
import PencilKit

struct NotePreviewsGrid: View {
    @Binding var subject: Subject
    
    // Add this flag to prevent infinite update loops
    @State private var isFirstAppearance = true
    
    // Explicit initializer to avoid ambiguity
    init(subject: Binding<Subject>) {
        self._subject = subject
        print("🔍 NotePreviewsGrid initialized with subject: \(subject.wrappedValue.name)")
    }
    
    // Example grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(subject.notes.indices, id: \.self) { index in
                    NavigationLink {
                        NoteDetailView(note: $subject.notes[index], subjectID: subject.id)
                    } label: {
                        noteCardView(for: index)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle(subject.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: createNewNote) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            // Only trigger updates on the first appearance to avoid loops
            if isFirstAppearance {
                print("🔍 NotePreviewsGrid onAppear - FIRST TIME - subject: \(subject.name)")
                isFirstAppearance = false
            } else {
                print("🔍 NotePreviewsGrid onAppear - REPEAT - subject: \(subject.name)")
            }
        }
        // Only update when disappearing, not when appearing
        .onDisappear {
            print("🔍 NotePreviewsGrid onDisappear - subject: \(subject.name)")
        }
    }
    
    private func noteCardView(for index: Int) -> some View {
        let note = subject.notes[index]

        // Compute the forced-first-page thumbnail
        let thumbnailImage: UIImage = {
            // 1. If there's no drawing data, return an empty UIImage
            guard !note.drawingData.isEmpty else { return UIImage() }

            // 2. Attempt to load a PKDrawing
            guard let loadedDrawing = try? PKDrawing(data: note.drawingData),
                  !loadedDrawing.strokes.isEmpty else {
                return UIImage()
            }

            // 3. Force a letter-size rectangle (8.5" x 11" at 72DPI)
            let firstPageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

            // 4. Scale it down to fit a ~100pt height
            let scale: CGFloat = 0.15

            // 5. Render a UIImage from that forced rectangle
            return loadedDrawing.image(from: firstPageRect, scale: scale)
        }()

        // Side effect print outside the view builder
        let _ = print("Thumbnail size = \(thumbnailImage.size)")

        return VStack(alignment: .leading) {
            // Show the thumbnail if valid
            if thumbnailImage.size.width > 0 && thumbnailImage.size.height > 0 {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
            } else {
                // Fallback placeholder
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 100)
            }

            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundColor(.primary)

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
    
    // Function to create a new note and navigate to it
    private func createNewNote() {
        print("🔍 Creating new note")
        // Create a blank untitled note by default
        let newNote = Note(title: "", drawingData: PKDrawing().dataRepresentation())
        subject.notes.append(newNote)
    }
}

