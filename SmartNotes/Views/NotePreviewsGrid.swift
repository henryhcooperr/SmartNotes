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
        VStack(alignment: .leading) {
            // Generate and display thumbnail of the note's drawing
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 100)
            
            Text(subject.notes[index].title.isEmpty ? "Untitled Note" : subject.notes[index].title)
                .font(.headline)
                .lineLimit(1)
                .foregroundColor(.primary)  // Ensure text is visible on both light/dark mode
            
            // Format the date
            Text(subject.notes[index].dateCreated, format: .dateTime.month().day().year())
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
    
    // Function to create a new note and navigate to it
    private func createNewNote() {
        print("🔍 Creating new note")
        // Create a blank untitled note by default
        let newNote = Note(title: "", drawingData: PKDrawing().dataRepresentation())
        subject.notes.append(newNote)
    }
}
