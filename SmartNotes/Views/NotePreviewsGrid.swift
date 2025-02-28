import SwiftUI
import PencilKit

struct NotePreviewsGrid: View {
    @Binding var subject: Subject
    
    // MARK: - View State
    @State private var isFirstAppearance = true
    @State private var viewMode: ViewMode = .bigGrid
    
    // One namespace for the entire screen
    @Namespace private var animationNamespace
    
    // MARK: - Enum for Layout Modes
    enum ViewMode: String, CaseIterable, Identifiable {
        case bigGrid = "Big Grid"
        case list = "List"
        case compact = "Compact"
        
        var id: String { rawValue }
        
        var iconName: String {
            switch self {
            case .bigGrid: return "square.grid.2x2.fill"
            case .list:    return "list.bullet"
            case .compact: return "rectangle.compress.vertical"
            }
        }
    }
    
    init(subject: Binding<Subject>) {
        self._subject = subject
    }
    
    var body: some View {
        ZStack {
            if subject.notes.isEmpty {
                emptyStateView
            } else {
                layoutContent
            }
        }
        .navigationTitle(subject.name)
        .toolbar {
            if !subject.notes.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    viewModePicker
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createNewNote) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            if isFirstAppearance {
                isFirstAppearance = false
            }
        }
        // Animate layout changes
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: subject.notes)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewMode)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Text("No Notes Yet!")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Button {
                withAnimation {
                    createNewNote()
                    viewMode = .list
                }
            } label: {
                Label("Add Note", systemImage: "plus.circle.fill")
                    .font(.title2)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
        .transition(.opacity) // simple fade
    }
    
    // MARK: - Main LayoutContent
    @ViewBuilder
    private var layoutContent: some View {
        switch viewMode {
        case .bigGrid:
            bigGridView
        case .list:
            listView
        case .compact:
            compactView
        }
    }
    
    // MARK: - Big Grid
    private var bigGridView: some View {
        // Large adaptive columns:
        let columns = [
            GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 20)
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(subject.notes.indices, id: \.self) { i in
                    NavigationLink {
                        NoteDetailView(note: $subject.notes[i], subjectID: subject.id)
                    } label: {
                        // Provide the note + layout style + namespace
                        NoteCardView(
                            note: subject.notes[i],
                            subject: subject,
                            layout: .bigGrid,
                            namespace: animationNamespace
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    // MARK: - List
    private var listView: some View {
        List {
            ForEach(subject.notes.indices, id: \.self) { i in
                NavigationLink {
                    NoteDetailView(note: $subject.notes[i], subjectID: subject.id)
                } label: {
                    NoteCardView(
                        note: subject.notes[i],
                        subject: subject,
                        layout: .list,
                        namespace: animationNamespace
                    )
                }
            }
        }
    }
    
    // MARK: - Compact
    private var compactView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(subject.notes.indices, id: \.self) { i in
                    NavigationLink {
                        NoteDetailView(note: $subject.notes[i], subjectID: subject.id)
                    } label: {
                        NoteCardView(
                            note: subject.notes[i],
                            subject: subject,
                            layout: .compact,
                            namespace: animationNamespace
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Create new note
    private func createNewNote() {
        let newNote = Note(
            title: "New Note",
            drawingData: PKDrawing().dataRepresentation()
        )
        subject.notes.append(newNote)
    }
    
    // MARK: - View Mode Picker
    private var viewModePicker: some View {
        Picker("Layout Mode", selection: $viewMode) {
            ForEach(ViewMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.iconName)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 300)
    }
}

// MARK: - Single Card View with Sub-Element Geometry Effects
fileprivate struct NoteCardView: View {
    let note: Note
    let subject: Subject
    
    // Layouts we want to support
    enum CardLayout {
        case bigGrid, list, compact
    }
    let layout: CardLayout
    
    let namespace: Namespace.ID
    
    var body: some View {
        switch layout {
        case .bigGrid:
            bigGridCard
        case .list:
            listCard
        case .compact:
            compactCard
        }
    }
    
    // MARK: - Big Grid Card
    private var bigGridCard: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .matchedGeometryEffect(id: "background-\(note.id)",
                                       in: namespace)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                thumbnail
                    .frame(height: 180)
                    .cornerRadius(8)
                    .matchedGeometryEffect(id: "thumbnail-\(note.id)",
                                           in: namespace)
                
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.headline)
                    .matchedGeometryEffect(id: "title-\(note.id)",
                                           in: namespace)
                
                Text(note.dateCreated, format: .dateTime.year().month().day())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .matchedGeometryEffect(id: "date-\(note.id)",
                                           in: namespace)
                
                Text(subject.name)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background(subject.color)
                    .cornerRadius(6)
                    .matchedGeometryEffect(id: "subject-\(note.id)",
                                           in: namespace)
            }
            .padding()
        }
        .frame(minWidth: 0)
    }
    
    // MARK: - List Card
    private var listCard: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 60, height: 80)
                .cornerRadius(4)
                .matchedGeometryEffect(id: "thumbnail-\(note.id)",
                                       in: namespace)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.headline)
                    .matchedGeometryEffect(id: "title-\(note.id)",
                                           in: namespace)
                
                Text(note.dateCreated, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .matchedGeometryEffect(id: "date-\(note.id)",
                                           in: namespace)
                
                Text(subject.name)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .foregroundColor(.white)
                    .background(subject.color)
                    .cornerRadius(4)
                    .matchedGeometryEffect(id: "subject-\(note.id)",
                                           in: namespace)
            }
            
            Spacer()
        }
        .background(
            // We can still morph the background if we want:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.clear)
                .matchedGeometryEffect(id: "background-\(note.id)",
                                       in: namespace)
        )
        .padding(.vertical, 6)
    }
    
    // MARK: - Compact Card
    private var compactCard: some View {
        HStack {
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.subheadline)
                .matchedGeometryEffect(id: "title-\(note.id)",
                                       in: namespace)
            
            Spacer()
            
            Text(note.dateCreated, format: .dateTime.month(.abbreviated).day())
                .font(.caption2)
                .foregroundColor(.secondary)
                .matchedGeometryEffect(id: "date-\(note.id)",
                                       in: namespace)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6))
                .matchedGeometryEffect(id: "background-\(note.id)",
                                       in: namespace)
        )
        // We could optionally put the subject name somewhere else or omit it in compact view
    }
    
    // MARK: - Thumbnail
    @ViewBuilder
    private var thumbnail: some View {
        // Attempt to create a small PKDrawing thumbnail
        if !note.drawingData.isEmpty,
           let drawing = try? PKDrawing(data: note.drawingData),
           !drawing.strokes.isEmpty {
            
            let image = drawing.image(
                from: CGRect(x: 0, y: 0, width: 612, height: 792),
                scale: 0.2
            )
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            // Fallback placeholder
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
        }
    }
}
