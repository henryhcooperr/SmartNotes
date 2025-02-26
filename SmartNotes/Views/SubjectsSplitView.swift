//
//  SubjectsSplitView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI

struct SubjectsSplitView: View {
    // Binding to the subjects array
    @Binding var subjects: [Subject]
    // Callback for when a subject is updated
    var onSubjectChange: (Subject) -> Void
    
    // The subject currently selected in the sidebar
    @State private var selectedSubject: Subject?
    
    // For searching subjects or notes (optional).
    @State private var searchText: String = ""
    
    // State to track when we're adding a new subject
    @State private var isAddingNewSubject = false
    @State private var newSubjectName = ""
    @State private var newSubjectColor = "blue"
    
    // Available color options
    let colorOptions = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]
    
    init(subjects: Binding<[Subject]>, onSubjectChange: @escaping (Subject) -> Void) {
        self._subjects = subjects
        self.onSubjectChange = onSubjectChange
    }
    
    var body: some View {
        NavigationSplitView {
            // SIDEBAR
            sidebarView
        } detail: {
            // MAIN DETAIL
            detailView
        }
        .sheet(isPresented: $isAddingNewSubject) {
            addSubjectView
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack {
            // Search bar at top
            TextField("Search", text: $searchText)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding()
            
            // The list of subjects
            List(selection: $selectedSubject) {
                ForEach(subjects) { subject in
                    // Color circle + subject name
                    HStack {
                        Circle()
                            .fill(subject.color)
                            .frame(width: 12, height: 12)
                        Text(subject.name)
                    }
                    .tag(subject) // Identifies which subject is selected
                }
                .onDelete(perform: deleteSubjects)
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Subjects")
            .toolbar {
                // Add new subject
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isAddingNewSubject = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    // MARK: - Detail
    
    private var detailView: some View {
        Group {
            if let subject = selectedSubject {
                if let index = subjects.firstIndex(where: { $0.id == subject.id }) {
                    // Create explicit binding to the subject in the array
                    let subjectBinding = $subjects[index]
                    
                    NavigationStack {
                        NotePreviewsGrid(subject: subjectBinding)
                            .onChange(of: subjects[index]) { newValue in
                                onSubjectChange(newValue)
                            }
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
    
    // MARK: - Functions
    
    private func deleteSubjects(at offsets: IndexSet) {
        subjects.remove(atOffsets: offsets)
    }
    
    /// We need a binding to the selectedSubject in the array,
    /// so changes in child views can update the original array.
    private func binding(for subject: Subject) -> Binding<Subject>? {
        guard let index = subjects.firstIndex(where: { $0.id == subject.id }) else {
            return nil
        }
        return $subjects[index]
    }
    
    // View for adding a new subject
    private var addSubjectView: some View {
        NavigationView {
            Form {
                Section(header: Text("Subject Details")) {
                    TextField("Subject Name", text: $newSubjectName)
                    
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
            .navigationBarItems(
                leading: Button("Cancel") {
                    isAddingNewSubject = false
                    newSubjectName = ""
                },
                trailing: Button("Add") {
                    let newSubject = Subject(name: newSubjectName, notes: [], colorName: newSubjectColor)
                    subjects.append(newSubject)
                    isAddingNewSubject = false
                    newSubjectName = ""
                    // Select the newly created subject
                    selectedSubject = newSubject
                }
                .disabled(newSubjectName.isEmpty)
            )
        }
    }
    
    // Helper to convert string color names to SwiftUI Color
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
