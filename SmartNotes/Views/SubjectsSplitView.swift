//
//  SubjectsSplitView.swift
//  SmartNotes
//
//  Allows user to pick both color & icon for each subject using:
//    - A color palette of tappable circles (instead of a dropdown)
//    - A distinct text field with subtle background for the subject name
//    - An enhanced icon grid with bigger spacing & subtler highlight
//    - Consistent typography & alignment for section headers
//

import SwiftUI

// MARK: - Events for Sidebar Management
struct SidebarEvents {
    struct CloseSidebar: Event {
        static var description: String = "Request to close the sidebar"
    }
    
    struct SidebarVisibilityChanged: Event {
        static var description: String = "Sidebar visibility state changed"
        let isVisible: Bool
    }
}

struct SubjectsSplitView: View {
    // Use the EventStore instead of direct state binding
    @EnvironmentObject var eventStore: EventStore
    
    // Subscription manager for events
    private let subscriptionManager = SubscriptionManager()
    
    // State for UI interaction that doesn't need to be in global state
    @State private var selectedSubjectID: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    // States for adding a new subject
    @State private var isAddingNewSubject = false
    @State private var newSubjectName = ""
    @State private var newSubjectColor = "blue"
    @State private var newSubjectIcon = "book.closed"
    @State private var isInitialSelection = true
    
    // State for renaming a subject
    @State private var isRenamingSubject = false
    @State private var subjectToRename: Subject?
    @State private var renamedSubjectName = ""
    
    // Color & Icon options
    let colorOptions = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]
    let iconOptions = [
        "function", "clock", "atom", "paintpalette", "book.closed",
        "pencil.and.outline", "star", "folder", "tray", "graduationcap",
        "calendar", "archivebox", "trash", "rectangle.stack", "camera",
        "music.note.list", "bag", "doc.text.magnifyingglass", "envelope", "guitar"
    ]
    
    // Computed properties for accessing state
    private var subjects: [Subject] {
        eventStore.state.contentState.subjects
    }
    
    private var searchText: String {
        eventStore.state.uiState.searchText
    }
    
    // Selected subject from the ID
    private var selectedSubject: Subject? {
        guard let id = selectedSubjectID else { return nil }
        return subjects.first { $0.id == id }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            detailView
        }
        .sheet(isPresented: $isAddingNewSubject) {
            addSubjectView
        }
        .sheet(isPresented: $isRenamingSubject) {
            renameSubjectView
        }
        .onAppear {
            // Automatically select the first subject on first appearance, if available
            if isInitialSelection, !subjects.isEmpty, selectedSubjectID == nil {
                selectedSubjectID = subjects[0].id
                isInitialSelection = false
            }
            
            // Subscribe to CloseSidebar events using EventBus
            subscriptionManager.subscribe(SidebarEvents.CloseSidebar.self) { _ in
                // Close the sidebar by setting visibility to detailOnly
                columnVisibility = .detailOnly
                
                // Publish event that sidebar visibility changed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    EventBus.shared.publish(SidebarEvents.SidebarVisibilityChanged(isVisible: false))
                }
            }
        }
        .onDisappear {
            // Clean up subscriptions when view disappears
            subscriptionManager.clearAll()
        }
        // Monitor for columnVisibility changes
        .onChange(of: columnVisibility) { _, newValue in
            // When visibility changes, publish an event
            let isVisible = newValue != .detailOnly
            EventBus.shared.publish(SidebarEvents.SidebarVisibilityChanged(isVisible: isVisible))
        }
    }
    
    // MARK: - Sidebar
    private var sidebarView: some View {
        VStack(spacing: 0) {
            headerBanner
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search subjects...", text: Binding(
                    get: { self.searchText },
                    set: { newValue in
                        eventStore.dispatch(SettingsAction.updateSearchText(text: newValue))
                    }
                ))
                .textFieldStyle(.plain)
                .font(.subheadline)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
            )
            .padding(.horizontal)
            .padding(.top, 8)
            
            subjectList
            
            Spacer(minLength: 0)
        }
        // Optional blurred background
        .background(
            BlurView(style: .systemUltraThinMaterial)
                .edgesIgnoringSafeArea(.all)
        )
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Subjects")
                    .font(.system(size: 26, weight: .bold))
                    .padding(.leading, 2)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAddingNewSubject = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            }
        }
    }
    
    private var headerBanner: some View {
        ZStack {
            Color(.systemGray6)
                .frame(height: 44)
                .overlay(
                    Divider().offset(y: 22)
                )
        }
    }
    
    // MARK: - Subject List
    private var subjectList: some View {
        List {
            ForEach(filteredSubjects) { subject in
                SubjectRowView(subject: subject)
                    .listRowBackground(
                        subject.id == selectedSubjectID
                        ? Color.blue.opacity(0.1)
                        : Color(.systemBackground).opacity(0.8)
                    )
                    .contentShape(Rectangle()) // Ensure the entire row is tappable
                    .onTapGesture {
                        // Set selected subject on tap
                        selectedSubjectID = subject.id
                        eventStore.dispatch(SubjectAction.selectSubject(subject.id))
                    }
                    .contextMenu {
                        Button("Rename") {
                            renameSubject(subject)
                        }
                        Button(role: .destructive) {
                            deleteSubject(subject)
                        } label: {
                            Text("Delete")
                        }
                    }
            }
            .onDelete(perform: deleteSubjects)
        }
        .listStyle(.inset)
        .padding(.top, 4)
    }
    
    // MARK: - Detail View
    private var detailView: some View {
        Group {
            if let subject = selectedSubject {
                NavigationStack {
                    NotePreviewsGrid(subjectID: subject.id)
                }
            } else {
                Text("Select a subject")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Add Subject View
    private var addSubjectView: some View {
        NavigationView {
            Form {
                // SECTION: Subject Name
                // Subject Name Section
                Section {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                        
                        TextField("Enter subject name...", text: $newSubjectName)
                            .padding(8)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                        
                    }
                } header: {
                    Text("Subject Name")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Color Section
                Section {
                    ColorSelectionGrid(
                        colors: colorOptions,
                        selectedColor: $newSubjectColor
                    )
                } header: {
                    Text("Color")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Icon Section
                Section {
                    IconSelectionGrid(
                        iconOptions: iconOptions,
                        selectedIcon: $newSubjectIcon
                    )
                } header: {
                    Text("Icon")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("New Subject")
                            .font(.title)
                            .fontWeight(.bold)  
                    }
                }
            
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isAddingNewSubject = false
                        newSubjectName = ""
                        newSubjectIcon = "book.closed"
                        newSubjectColor = "blue"
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        // Dispatch action to create new subject
                        let newSubject = Subject(
                            name: newSubjectName,
                            notes: [],
                            colorName: newSubjectColor,
                            iconName: newSubjectIcon
                        )
                        eventStore.dispatch(
                            SubjectAction.addSubject(newSubject)
                        )
                        
                        // Reset UI state
                        isAddingNewSubject = false
                        newSubjectName = ""
                        newSubjectIcon = "book.closed"
                        newSubjectColor = "blue"
                        
                        // Select the newly created subject on the next UI update
                        DispatchQueue.main.async {
                            if let newSubject = subjects.last {
                                selectedSubjectID = newSubject.id
                                eventStore.dispatch(SubjectAction.selectSubject(newSubject.id))
                            }
                        }
                    }
                    .disabled(newSubjectName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Rename Subject View
    private var renameSubjectView: some View {
        NavigationView {
            Form {
                // Subject Name Section
                Section {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                        
                        TextField("Enter subject name...", text: $renamedSubjectName)
                            .padding(8)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                    }
                } header: {
                    Text("New Subject Name")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Rename Subject")
                        .font(.title)
                        .fontWeight(.bold)  
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isRenamingSubject = false
                        subjectToRename = nil
                        renamedSubjectName = ""
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Implementation for renaming the subject
                        if let subject = subjectToRename {
                            var updatedSubject = subject
                            updatedSubject.name = renamedSubjectName
                            
                            // Dispatch action to update the subject
                            eventStore.dispatch(
                                SubjectAction.updateSubject(updatedSubject)
                            )
                            
                            // Reset UI state
                            isRenamingSubject = false
                            subjectToRename = nil
                            renamedSubjectName = ""
                        }
                    }
                    .disabled(renamedSubjectName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    // Filter subjects by search text
    private var filteredSubjects: [Subject] {
        if searchText.isEmpty { return subjects }
        return subjects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func deleteSubjects(at offsets: IndexSet) {
        for index in offsets {
            deleteSubject(subjects[index])
        }
    }
    
    private func deleteSubject(_ subject: Subject) {
        eventStore.dispatch(SubjectAction.deleteSubject(subject.id))
        
        // If the deleted subject was selected, clear the selection
        if selectedSubjectID == subject.id {
            selectedSubjectID = nil
        }
    }
    
    private func renameSubject(_ subject: Subject) {
        // Initialize the rename dialog
        subjectToRename = subject
        renamedSubjectName = subject.name
        isRenamingSubject = true
    }
}

// MARK: - Subject Row
fileprivate struct SubjectRowView: View {
    let subject: Subject
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: subject.iconName)
                .foregroundColor(subject.color)
                .font(.system(size: 20, weight: .medium))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                if !subject.notes.isEmpty {
                    Text("\(subject.notes.count) note\(subject.notes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Small color circle on the right
            Circle()
                .fill(subject.color)
                .frame(width: 12, height: 12)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Color Selection Grid
fileprivate struct ColorSelectionGrid: View {
    let colors: [String]
    @Binding var selectedColor: String
    
    private let columns = [
        GridItem(.adaptive(minimum: 40, maximum: 60), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(colors, id: \.self) { colorName in
                ZStack {
                    let color = colorToSwiftUIColor(colorName)
                    
                    Circle()
                        .fill(color)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(
                                colorName == selectedColor
                                    ? Color.accentColor.opacity(0.6)
                                    : Color.clear,
                                lineWidth: 3
                            )
                        )
                }
                .onTapGesture {
                    selectedColor = colorName
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private func colorToSwiftUIColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "red":      return .red
        case "orange":   return .orange
        case "yellow":   return .yellow
        case "green":    return .green
        case "blue":     return .blue
        case "purple":   return .purple
        case "pink":     return .pink
        default:         return .gray
        }
    }
}

// MARK: - Icon Selection Grid
fileprivate struct IconSelectionGrid: View {
    let iconOptions: [String]
    @Binding var selectedIcon: String
    
    // More spacing for a friendlier layout
    private let columns = [
        GridItem(.adaptive(minimum: 50, maximum: 60), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(iconOptions, id: \.self) { iconName in
                ZStack {
                    // Subtle highlight for selected icon
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconName == selectedIcon
                              ? Color.accentColor.opacity(0.15)
                              : Color.clear)
                    
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .frame(height: 50)
                .onTapGesture {
                    selectedIcon = iconName
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Blur Background
fileprivate struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}
