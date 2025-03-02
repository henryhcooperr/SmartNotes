//
//  SubjectsListView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  This version displays subjects in a grid with clickable/tappable cards.
//  It retains a floating action button and a quick text field
//  for creating new subjects at the bottom.

import SwiftUI

struct SubjectsListView: View {
    // We'll store an array of subjects in memory
    @State private var subjects: [Subject] = [
        // Provide a colorName and iconName for each subject
        Subject(name: "Math", notes: [], colorName: "blue", iconName: "function"),
        Subject(name: "History", notes: [], colorName: "red", iconName: "book")
    ]
    
    // Tracks the new subject name when we want to create one
    @State private var newSubjectName: String = ""
    
    // Example columns for our grid
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 300), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // The main ScrollView + LazyVGrid for the subject "cards"
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach($subjects) { $subject in
                                NavigationLink(destination: NotesListView(subject: $subject)) {
                                    SubjectCardView(subject: subject)
                                }
                                .buttonStyle(.plain) // So it looks more like a card tap than a button
                            }
                            .onDelete(perform: deleteSubject)
                        }
                        .padding()
                    }
                    .navigationTitle("Subjects")
                    .toolbar {
                        // Edit button for swipe-to-delete if you want it
                        ToolbarItem(placement: .navigationBarLeading) {
                            EditButton()
                        }
                    }
                    
                    // A simple text field + button for quick subject creation
                    HStack {
                        TextField("New Subject Name", text: $newSubjectName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        Button(action: addSubject) {
                            Image(systemName: "plus")
                                .padding(.trailing)
                        }
                        .disabled(newSubjectName.isEmpty)
                    }
                }
                
                // Floating Action Button (FAB) to add a new subject
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            // Haptic feedback
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            addSubject()
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .padding()
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.accentColor))
                                .shadow(radius: 5)
                        }
                        .padding()
                    }
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func addSubject() {
        // Provide a colorName for newly created subjects, pick an icon if needed
        let newSubject = Subject(name: newSubjectName, notes: [], colorName: "gray", iconName: "doc.text")
        subjects.append(newSubject)
        newSubjectName = ""
    }
    
    private func deleteSubject(at offsets: IndexSet) {
        subjects.remove(atOffsets: offsets)
    }
}

// MARK: - Subject Card
/// A simple card UI showing the subject's icon, name, and color.
fileprivate struct SubjectCardView: View {
    let subject: Subject
    
    var body: some View {
        VStack(spacing: 8) {
            // Display the subject's icon
            Image(systemName: subject.iconName)
                .resizable()
                .scaledToFit()
                .foregroundColor(subject.color)
                .frame(height: 40)
            
            // Subject title
            Text(subject.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Optional note count, if desired
            if !subject.notes.isEmpty {
                Text("\(subject.notes.count) notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
}
