//
//  MinimalNoteView.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI

// Absolutely minimal view with just essential functionality
struct MinimalNoteView: View {
    // Use a local copy of the note data, not a binding
    let noteID: UUID
    let initialTitle: String
    
    // Debug ID to track instance
    let instanceID = UUID().uuidString.prefix(6)
    
    init(note: Note) {
        print("🚨 STEP 1: MinimalNoteView init started for note: \(note.title)")
        self.noteID = note.id
        self.initialTitle = note.title
        print("🚨 STEP 2: MinimalNoteView init completed")
    }
    
    var body: some View {
        print("🚨 STEP 3: MinimalNoteView body evaluation started")
        
        let result = VStack(spacing: 16) {
            // Debug header
            Text("MINIMAL DEBUG VIEW (ID: \(instanceID))")
                .font(.caption)
                .foregroundColor(.red)
                .padding(.top)
            
            Text("Note ID: \(noteID)")
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Simple title display - no binding
            Text("Note Title: \(initialTitle)")
                .font(.headline)
                .padding()
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)
            
            Divider()
            
            // Status display
            Text("If you can see this, the view is rendering properly")
                .foregroundColor(.green)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            
            Spacer()
            
            // Debug footer with timestamp
            let timestamp = Date().formatted(date: .abbreviated, time: .standard)
            Text("View loaded at: \(timestamp)")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.bottom)
        }
        .padding()
        .onAppear {
            print("🚨 STEP 5: MinimalNoteView onAppear called")
        }
        
        print("🚨 STEP 4: MinimalNoteView body evaluation completed")
        return result
    }
}

// Extension to create a completely decoupled grid
extension NotePreviewsGrid {
    // Replace the whole grid with this ultra-simple version for testing
    var ultraSimpleGrid: some View {
        VStack {
            Text("EMERGENCY DEBUG MODE")
                .font(.headline)
                .foregroundColor(.red)
                .padding()
            
            Divider()
            
            ForEach(subject.notes.indices, id: \.self) { index in
                NavigationLink {
                    // Just pass the note value, not a binding
                    MinimalNoteView(note: subject.notes[index])
                } label: {
                    HStack {
                        Text("\(index + 1).")
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading) {
                            Text(subject.notes[index].title.isEmpty ? "Untitled" : subject.notes[index].title)
                            Text("Created: \(subject.notes[index].dateCreated.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
            }
            
            Spacer()
            
            Button {
                let newNote = Note(title: "Test Note", drawingData: Data())
                subject.notes.append(newNote)
            } label: {
                Text("Add Test Note")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .navigationTitle("Ultra Debug Mode")
    }
}
