//
//  SubjectListView.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  This file provides a simpler list of subjects but now includes a floating
//  action button (FAB) for adding new subjects. It retains the basic list layout
//  for each subject, which navigates to the NotesListView.
//
import SwiftUI

struct SubjectsListView: View {
    // We'll store an array of subjects in memory
    @State private var subjects: [Subject] = [
        // Provide a colorName for each subject
        Subject(name: "Math", notes: [], colorName: "blue"),
        Subject(name: "History", notes: [], colorName: "red")
    ]

    // Tracks the new subject name when we want to create one
    @State private var newSubjectName: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    List {
                        ForEach($subjects) { $subject in
                            NavigationLink(destination: NotesListView(subject: $subject)) {
                                Text(subject.name)
                            }
                        }
                        .onDelete(perform: deleteSubject)
                    }
                    .navigationTitle("Subjects")
                    .toolbar {
                        // Edit button for swipe-to-delete
                        ToolbarItem(placement: .navigationBarLeading) {
                            EditButton()
                        }
                    }
                    
                    // A simple text field + button remains for quick subject creation
                    // (Alternatively, you could remove this in favor of only the FAB)
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
                
                // Floating Action Button to add a new subject
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
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
        // Provide a colorName for newly created subjects, too
        let newSubject = Subject(name: newSubjectName, notes: [], colorName: "gray")
        subjects.append(newSubject)
        newSubjectName = ""
    }

    private func deleteSubject(at offsets: IndexSet) {
        subjects.remove(atOffsets: offsets)
    }
}
