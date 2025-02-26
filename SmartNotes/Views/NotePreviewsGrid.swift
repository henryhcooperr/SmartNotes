import SwiftUI
import PencilKit

struct NotePreviewsGrid: View {
    @Binding var subject: Subject
    
    // Flag to prevent infinite update loops
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
                        NoteDetailView(note: $subject.notes[index])
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
            // Prevent onChange handlers from firing repeatedly
            if isFirstAppearance {
                print("🔍 NotePreviewsGrid onAppear - first time")
                isFirstAppearance = false
            }
        }
    }
    
    private func noteCardView(for index: Int) -> some View {
        VStack(alignment: .leading) {
            // Simple placeholder for now - no complex thumbnail generation
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 100)
                .overlay(
                    Text(subject.notes[index].title.isEmpty ? "Untitled" : subject.notes[index].title)
                        .foregroundColor(.secondary)
                )
            
            Text(subject.notes[index].title.isEmpty ? "Untitled Note" : subject.notes[index].title)
                .font(.headline)
                .lineLimit(1)
                .foregroundColor(.primary)
            
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
        // Create a blank untitled note by default - with empty data
        let newNote = Note(title: "", drawingData: Data())
        subject.notes.append(newNote)
    }
}
