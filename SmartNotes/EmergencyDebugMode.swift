//
//  EmergencyDebugMode.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI
import PencilKit

// A completely standalone debugging environment
struct EmergencyDebugMode: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedSubjectIndex = 0
    @State private var debugMessage = "No operations performed yet"
    @State private var isShowingNoteView = false
    @State private var selectedNote: Note?
    
    var body: some View {
        NavigationView {
            VStack {
                Text("EMERGENCY DEBUG MODE")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding()
                
                Divider()
                
                // Subject selector
                VStack(alignment: .leading) {
                    Text("1. Select a subject:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Picker("Subject", selection: $selectedSubjectIndex) {
                        ForEach(0..<dataManager.subjects.count, id: \.self) { index in
                            Text(dataManager.subjects[index].name).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                if selectedSubjectIndex < dataManager.subjects.count {
                    let subject = dataManager.subjects[selectedSubjectIndex]
                    
                    // Notes in selected subject
                    VStack(alignment: .leading) {
                        Text("2. Available notes in \(subject.name):")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if subject.notes.isEmpty {
                            Text("No notes available")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            List {
                                ForEach(subject.notes) { note in
                                    Button {
                                        selectedNote = note
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                                Text(note.dateCreated, format: .dateTime.month().day().year())
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedNote?.id == note.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .frame(height: 200)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical)
                    
                    Divider()
                    
                    // Operations
                    VStack(alignment: .leading) {
                        Text("3. Actions:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Button {
                                createTestNote()
                            } label: {
                                Text("Create Test Note")
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            Button {
                                viewSelectedNote()
                            } label: {
                                Text("View Selected Note")
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(selectedNote != nil ? Color.green : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .disabled(selectedNote == nil)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                
                Divider()
                
                // Debug output
                VStack(alignment: .leading) {
                    Text("Debug Output:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(debugMessage)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Debug Tools")
            .sheet(isPresented: $isShowingNoteView) {
                NavigationView {
                    if let note = selectedNote {
                        MinimalNoteView(note: note)
                            .navigationTitle("Test View")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Close") {
                                        isShowingNoteView = false
                                    }
                                }
                            }
                    } else {
                        Text("No note selected")
                    }
                }
            }
        }
    }
    
    // Create a test note in the selected subject
    private func createTestNote() {
        guard selectedSubjectIndex < dataManager.subjects.count else {
            debugMessage = "Error: Invalid subject index"
            return
        }
        
        let timestamp = Date().formatted(date: .numeric, time: .standard)
        let newNote = Note(
            title: "Test Note - \(timestamp)",
            drawingData: PKDrawing().dataRepresentation()
        )
        
        // Add the note to the subject
        dataManager.subjects[selectedSubjectIndex].notes.append(newNote)
        dataManager.saveData()
        
        // Auto-select the new note
        selectedNote = newNote
        
        debugMessage = "Created and selected new test note: \(newNote.title)"
    }
    
    // View the selected note in the minimal viewer
    private func viewSelectedNote() {
        guard selectedNote != nil else {
            debugMessage = "Error: No note selected"
            return
        }
        
        debugMessage = "Opening note: \(selectedNote?.title ?? "Unknown")"
        isShowingNoteView = true
    }
}

// Simple debug button overlay that can be added to any view
struct DebugButtonOverlay: ViewModifier {
    @State private var isShowingDebugMode = false
    @EnvironmentObject var dataManager: DataManager
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            isShowingDebugMode = true
                        } label: {
                            Text("DEBUG")
                                .font(.caption)
                                .padding(8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                }
            )
            .fullScreenCover(isPresented: $isShowingDebugMode) {
                EmergencyDebugMode()
                    .environmentObject(dataManager)
            }
    }
}

// Extension to View protocol (not just MainView)
extension View {
    func withDebugButton() -> some View {
        self.modifier(DebugButtonOverlay())
    }
}
