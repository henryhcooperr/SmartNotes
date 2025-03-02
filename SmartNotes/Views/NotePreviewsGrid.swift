import SwiftUI
import PencilKit

struct NotePreviewsGrid: View {
    @Binding var subject: Subject
    
    @State private var viewMode: ViewMode = .bigGrid
    @Namespace private var animationNamespace
    
    // Multi-selection
    @State private var isSelecting = false
    @State private var selectedNoteIDs = Set<UUID>()
    
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
                    if isSelecting {
                        Button("Done") {
                            exitSelectionMode()
                        }
                    } else {
                        viewModePicker
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelecting {
                        if !selectedNoteIDs.isEmpty {
                            Button(role: .destructive) {
                                deleteSelectedNotes()
                            } label: {
                                Image(systemName: "trash")
                            }
                        } else {
                            Image(systemName: "trash")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            createNewNote()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        // Animate changes to notes, selection, or layout
        .animation(.default, value: subject.notes)
        .animation(.default, value: isSelecting)
        .animation(.default, value: selectedNoteIDs)
        .animation(.default, value: viewMode)
    }
    
    // MARK: - Main Layout Switch
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
        let columns = [
            GridItem(.adaptive(minimum: 500, maximum: 700), spacing: 20)
        ]
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(subject.notes.indices, id: \.self) { i in
                    let note = subject.notes[i]
                    
                    // Always use a NavigationLink for normal taps
                    NavigationLink {
                        NoteDetailView(note: $subject.notes[i], subjectID: subject.id)
                    } label: {
                        NoteCardView(
                            note: note,
                            subject: subject,
                            layout: .bigGrid,
                            namespace: animationNamespace,
                            isSelecting: isSelecting,
                            isSelected: selectedNoteIDs.contains(note.id),
                            onLongPress: { toggleSelection(note: note) }
                        )
                        .matchedGeometryEffect(id: note.id, in: animationNamespace)
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
                let note = subject.notes[i]
                NavigationLink {
                    NoteDetailView(note: $subject.notes[i], subjectID: subject.id)
                } label: {
                    NoteCardView(
                        note: note,
                        subject: subject,
                        layout: .list,
                        namespace: animationNamespace,
                        isSelecting: isSelecting,
                        isSelected: selectedNoteIDs.contains(note.id),
                        onLongPress: { toggleSelection(note: note) }
                    )
                    .matchedGeometryEffect(id: note.id, in: animationNamespace)
                }
            }
        }
    }
    
    // MARK: - Compact
    private var compactView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(subject.notes.indices, id: \.self) { i in
                    let note = subject.notes[i]
                    NavigationLink {
                        NoteDetailView(note: $subject.notes[i], subjectID: subject.id)
                    } label: {
                        NoteCardView(
                            note: note,
                            subject: subject,
                            layout: .compact,
                            namespace: animationNamespace,
                            isSelecting: isSelecting,
                            isSelected: selectedNoteIDs.contains(note.id),
                            onLongPress: { toggleSelection(note: note) }
                        )
                        .matchedGeometryEffect(id: note.id, in: animationNamespace)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Text("No Notes Yet!")
                .font(.largeTitle)
            Button {
                createNewNote()
                viewMode = .list
            } label: {
                Label("Add Note", systemImage: "plus.circle.fill")
                    .font(.title2)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Actions
    private func createNewNote() {
        subject.notes.append(
            Note(title: "New Note",
                 drawingData: PKDrawing().dataRepresentation())
        )
    }
    
    private func toggleSelection(note: Note) {
        // If not already selecting, enter selection mode
        if !isSelecting {
            isSelecting = true
        }
        // Toggle this note's membership in the selected set
        if selectedNoteIDs.contains(note.id) {
            selectedNoteIDs.remove(note.id)
        } else {
            selectedNoteIDs.insert(note.id)
        }
    }
    
    private func deleteSelectedNotes() {
        subject.notes.removeAll { selectedNoteIDs.contains($0.id) }
        exitSelectionMode()
    }
    
    private func exitSelectionMode() {
        isSelecting = false
        selectedNoteIDs.removeAll()
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

// MARK: - Note Card View
fileprivate struct NoteCardView: View {
    let note: Note
    let subject: Subject
    
    enum CardLayout { case bigGrid, list, compact }
    let layout: CardLayout
    
    let namespace: Namespace.ID
    
    let isSelecting: Bool
    let isSelected: Bool
    
    // Called on a long press. We can toggle selection this way.
    let onLongPress: () -> Void
    
    var body: some View {
        Group {
            switch layout {
            case .bigGrid:
                bigGridCard
            case .list:
                listCard
            case .compact:
                compactCard
            }
        }
        // Long press toggles selection.
        // A normal tap is handled by NavigationLink for opening the note.
        .onLongPressGesture {
            onLongPress()
        }
    }
    
    // MARK: - Big Grid Card
    private var bigGridCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                thumbnail
                    .frame(height: 180)
                    .cornerRadius(8)
                
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.headline)
                
                Text(note.dateCreated, format: .dateTime.year().month().day())
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
            
            if isSelecting {
                selectionIndicator
            }
        }
    }
    
    // MARK: - List Card
    private var listCard: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 60, height: 80)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.headline)
                
                Text(note.dateCreated, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(subject.name)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .foregroundColor(.white)
                    .background(subject.color)
                    .cornerRadius(4)
            }
            Spacer()
            
            if isSelecting {
                selectionIndicator
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Compact Card
    private var compactCard: some View {
        HStack {
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.subheadline)
            Spacer()
            Text(note.dateCreated, format: .dateTime.month(.abbreviated).day())
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if isSelecting {
                selectionIndicator
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Thumbnail Helper
    @ViewBuilder
    private var thumbnail: some View {
        Image(fromUIImage: ThumbnailGenerator.generateThumbnail(
            from: note,
            size: CGSize(width: 300, height: 200),
            highQuality: true
        ))
        .resizable()
        .aspectRatio(contentMode: .fill)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .background(Color.white)
    }
    
    // MARK: - Selection Indicator
    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.white)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .padding(8)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 8, y: 8)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}
