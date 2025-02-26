import SwiftUI
import PencilKit
// Import the shared types
// If this is in the same module, you don't need any additional import

struct NotePreviewsGrid: View {
    @Binding var subject: Subject
    @State private var newNoteIdentifier: NoteIdentifier? = nil
    @State private var editingNoteIdentifier: NoteIdentifier? = nil
    
    // Explicit initializer to avoid ambiguity
    init(subject: Binding<Subject>) {
        self._subject = subject
    }
    
    // Example grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(subject.notes.indices, id: \.self) { index in
                    noteCard(for: index)
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
        .sheet(item: $newNoteIdentifier) { identifier in
            NavigationView {
                if identifier.index < subject.notes.count {
                    NoteDetailView(note: $subject.notes[identifier.index])
                        .navigationBarItems(
                            trailing: Button("Save") {
                                // Ensure we keep any changes made to the new note
                                print("Saving new note: \(subject.notes[identifier.index].title)")
                                self.newNoteIdentifier = nil
                            }
                        )
                }
            }
        }
        .sheet(item: $editingNoteIdentifier) { identifier in
            NavigationView {
                if identifier.index < subject.notes.count {
                    NoteDetailView(note: $subject.notes[identifier.index])
                        .navigationBarItems(
                            trailing: Button("Save") {
                                // Ensure we keep any changes made to the edited note
                                print("Saving edited note: \(subject.notes[identifier.index].title)")
                                self.editingNoteIdentifier = nil
                            }
                        )
                }
            }
        }
    }
    
    private func noteCard(for index: Int) -> some View {
        // Create a custom card that opens the editing sheet when tapped
        Button {
            editingNoteIdentifier = NoteIdentifier(index: index)
        } label: {
            VStack(alignment: .leading) {
                // Placeholder for the note "thumbnail"
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 100)
                
                Text(subject.notes[index].title.isEmpty ? "Untitled Note" : subject.notes[index].title)
                    .font(.headline)
                    .lineLimit(1)
                
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
        .buttonStyle(PlainButtonStyle())
    }
    
    // Function to create a new note and navigate to it
    private func createNewNote() {
        // Create a blank untitled note by default
        let newNote = Note(title: "", drawingData: PKDrawing().toData())
        subject.notes.append(newNote)
        newNoteIdentifier = NoteIdentifier(index: subject.notes.count - 1)
    }
}
