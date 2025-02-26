//
//  DataManager.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI
import Combine

class DataManager: ObservableObject {
    @Published var subjects: [Subject] = []
    private let saveKey = "smartnotes.subjects"
    
    init() {
        loadData()
    }
    
    func loadData() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([Subject].self, from: data) {
                self.subjects = decoded
                return
            }
        }
        
        // Default subjects if no data exists
        self.subjects = [
            Subject(name: "Math", notes: [], colorName: "blue"),
            Subject(name: "History", notes: [], colorName: "red"),
            Subject(name: "Science", notes: [], colorName: "green")
        ]
    }
    
    func saveData() {
        if let encoded = try? JSONEncoder().encode(subjects) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    func addSubject(named name: String, color: String = "gray") {
        let newSubject = Subject(name: name, notes: [], colorName: color)
        subjects.append(newSubject)
        saveData()
    }
    
    func deleteSubject(at index: Int) {
        subjects.remove(at: index)
        saveData()
    }
    
    func updateSubject(_ subject: Subject) {
        if let index = subjects.firstIndex(where: { $0.id == subject.id }) {
            subjects[index] = subject
            saveData()
        }
    }
    
    func addNote(to subjectID: UUID, note: Note) {
        if let index = subjects.firstIndex(where: { $0.id == subjectID }) {
            subjects[index].notes.append(note)
            saveData()
        }
    }
    
    func updateNote(in subjectID: UUID, note: Note) {
        if let subjectIndex = subjects.firstIndex(where: { $0.id == subjectID }),
           let noteIndex = subjects[subjectIndex].notes.firstIndex(where: { $0.id == note.id }) {
            subjects[subjectIndex].notes[noteIndex] = note
            saveData()
        }
    }
    
    func deleteNote(from subjectID: UUID, at noteIndex: Int) {
        if let subjectIndex = subjects.firstIndex(where: { $0.id == subjectID }) {
            subjects[subjectIndex].notes.remove(at: noteIndex)
            saveData()
        }
    }
}
