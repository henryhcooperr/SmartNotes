//  SubjectsSplitView.swift
//  SmartNotes

import SwiftUI

struct SubjectsSplitView: View {
    @Binding var subjects: [Subject]
    var onSubjectChange: (Subject) -> Void
    
    @State private var selectedSubject: Subject?
    @State private var searchText: String = ""
    
    @State private var isAddingNewSubject = false
    @State private var newSubjectName = ""
    @State private var newSubjectColor = "blue"
    @State private var isInitialSelection = true
    
    let colorOptions = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]
    
    init(subjects: Binding<[Subject]>, onSubjectChange: @escaping (Subject) -> Void) {
        self._subjects = subjects
        self.onSubjectChange = onSubjectChange
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .sheet(isPresented: $isAddingNewSubject) {
            addSubjectView
        }
        .onAppear {
            if isInitialSelection, !subjects.isEmpty, selectedSubject == nil {
                selectedSubject = subjects[0]
                isInitialSelection = false
            }
        }
    }
    
    // MARK: - Sidebar
    private var sidebarView: some View {
        VStack(spacing: 0) {
            headerBanner
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search subjects...", text: $searchText)
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
    
    // MARK: - Header Banner
    private var headerBanner: some View {
        ZStack {
            Color(.systemGray6)
                .frame(height: 44)
                .overlay(
                    Divider()
                        .offset(y: 22)
                )
        }
    }
    
    // MARK: - Subject List
    private var subjectList: some View {
        List(selection: $selectedSubject) {
            ForEach(filteredSubjects) { subject in
                SubjectRowView(subject: subject)
                    .tag(subject)
                    .listRowBackground(
                        subject == selectedSubject
                        ? Color.blue.opacity(0.1)    // Subtle highlight for selected
                        : Color(.systemBackground).opacity(0.8)
                    )
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
                if let index = subjects.firstIndex(where: { $0.id == subject.id }) {
                    let subjectBinding = $subjects[index]
                    NavigationStack {
                        NotePreviewsGrid(subject: subjectBinding)
                    }
                } else {
                    Text("Subject not found")
                        .font(.title)
                        .foregroundColor(.red)
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
                Section(header: Text("Subject Details")) {
                    TextField("Subject Name", text: $newSubjectName)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Color", selection: $newSubjectColor) {
                        ForEach(colorOptions, id: \.self) { colorName in
                            HStack {
                                Circle()
                                    .fill(colorToSwiftUIColor(colorName))
                                    .frame(width: 20, height: 20)
                                Text(colorName.capitalized)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Subject")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isAddingNewSubject = false
                        newSubjectName = ""
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let newSubject = Subject(
                            name: newSubjectName,
                            notes: [],
                            colorName: newSubjectColor
                        )
                        subjects.append(newSubject)
                        isAddingNewSubject = false
                        newSubjectName = ""
                        selectedSubject = newSubject
                        onSubjectChange(newSubject)
                    }
                    .disabled(newSubjectName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private var filteredSubjects: [Subject] {
        if searchText.isEmpty { return subjects }
        return subjects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func deleteSubjects(at offsets: IndexSet) {
        subjects.remove(atOffsets: offsets)
    }
    private func deleteSubject(_ subject: Subject) {
        if let idx = subjects.firstIndex(where: { $0.id == subject.id }) {
            subjects.remove(at: idx)
        }
    }
    private func renameSubject(_ subject: Subject) {
        print("Renaming subject: \(subject.name)")
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

// MARK: - SubjectRowView
fileprivate struct SubjectRowView: View {
    let subject: Subject
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForSubject(subject.name))
                .foregroundColor(subject.color)
                .font(.system(size: 20, weight: .medium))
            
            VStack(alignment: .leading, spacing: 2) {
                // Make sure the text is always visible
                Text(subject.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)  // <-- Always primary color
                
                if !subject.notes.isEmpty {
                    Text("\(subject.notes.count) note\(subject.notes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Circle()
                .fill(subject.color)
                .frame(width: 12, height: 12)
        }
        .padding(.vertical, 6)
    }
    
    private func iconForSubject(_ name: String) -> String {
        let lowerName = name.lowercased()
        if lowerName.contains("math") { return "function" }
        if lowerName.contains("history") { return "clock" }
        if lowerName.contains("science") { return "atom" }
        if lowerName.contains("art") { return "paintpalette" }
        return "book.closed"
    }
}

// MARK: - Optional Blur View
fileprivate struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}
