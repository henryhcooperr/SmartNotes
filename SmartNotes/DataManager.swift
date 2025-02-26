//
//  DataManager.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI
import Combine
import UIKit

class DataManager: ObservableObject {
    @Published var subjects: [Subject] = []
    private let saveKey = "smartnotes.subjects"
    private var saveDebounceTimer: Timer?
    
    // Add flag to avoid excess saves
    private var isSaving = false
    private var pendingSaveNeeded = false
    
    init() {
        print("📊 DataManager initializing")
        loadData()
        
        // Register for app life cycle notifications to ensure data is saved
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveDataImmediately),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveDataImmediately),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadData() {
        print("📊 DataManager loading data")
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([Subject].self, from: data) {
                print("📊 Successfully decoded \(decoded.count) subjects")
                self.subjects = decoded
                return
            } else {
                print("📊 Failed to decode data")
            }
        } else {
            print("📊 No data found in UserDefaults")
        }
        
        // Default subjects if no data exists
        print("📊 Creating default subjects")
        self.subjects = [
            Subject(name: "Math", notes: [], colorName: "blue"),
            Subject(name: "History", notes: [], colorName: "red"),
            Subject(name: "Science", notes: [], colorName: "green")
        ]
    }
    
    // Schedule data saving with much longer debounce (3 seconds) to avoid UI freezing
    private func scheduleSave() {
        if isSaving {
            // If currently saving, mark that another save is needed
            pendingSaveNeeded = true
            return
        }
        
        print("📊 Scheduling save with 3-second debounce")
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.saveData()
        }
    }
    
    func saveData() {
        // Check if already saving
        if isSaving {
            pendingSaveNeeded = true
            print("📊 Save already in progress, will save again when complete")
            return
        }
        
        print("📊 DataManager saving data with \(subjects.count) subjects")
        isSaving = true
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            if let encoded = try? JSONEncoder().encode(self.subjects) {
                UserDefaults.standard.set(encoded, forKey: self.saveKey)
                print("📊 Data saved successfully to UserDefaults")
                
                DispatchQueue.main.async {
                    self.isSaving = false
                    
                    // If another save was requested while saving, schedule it now
                    if self.pendingSaveNeeded {
                        print("📊 Processing pending save request")
                        self.pendingSaveNeeded = false
                        self.scheduleSave()
                    }
                }
            } else {
                print("📊 Failed to encode subjects for saving")
                DispatchQueue.main.async {
                    self.isSaving = false
                }
            }
        }
    }
    
    @objc func saveDataImmediately() {
        print("📊 Saving data immediately")
        saveDebounceTimer?.invalidate()
        saveData()
    }
    
    func addSubject(named name: String, color: String = "gray") {
        print("📊 Adding subject: \(name)")
        let newSubject = Subject(name: name, notes: [], colorName: color)
        subjects.append(newSubject)
        scheduleSave()
    }
    
    func deleteSubject(at index: Int) {
        print("📊 Deleting subject at index: \(index)")
        subjects.remove(at: index)
        scheduleSave()
    }
    
    func updateSubject(_ subject: Subject) {
        print("📊 Updating subject: \(subject.name) with \(subject.notes.count) notes")
        if let index = subjects.firstIndex(where: { $0.id == subject.id }) {
            subjects[index] = subject
            scheduleSave()
        } else {
            print("📊 Error: Subject not found for update")
        }
    }
    
    func addNote(to subjectID: UUID, note: Note) {
        print("📊 Adding note to subject ID: \(subjectID)")
        if let index = subjects.firstIndex(where: { $0.id == subjectID }) {
            subjects[index].notes.append(note)
            // Touch the subject to mark it as modified
            subjects[index].touch()
            scheduleSave()
        } else {
            print("📊 Error: Subject not found for adding note")
        }
    }
    
    func updateNote(in subjectID: UUID, note: Note) {
        print("📊 Updating note in subject ID: \(subjectID)")
        if let subjectIndex = subjects.firstIndex(where: { $0.id == subjectID }),
           let noteIndex = subjects[subjectIndex].notes.firstIndex(where: { $0.id == note.id }) {
            subjects[subjectIndex].notes[noteIndex] = note
            // Touch the subject to mark it as modified
            subjects[subjectIndex].touch()
            scheduleSave()
        } else {
            print("📊 Error: Subject or Note not found for update")
        }
    }
    
    func deleteNote(from subjectID: UUID, at noteIndex: Int) {
        print("📊 Deleting note at index \(noteIndex) from subject ID: \(subjectID)")
        if let subjectIndex = subjects.firstIndex(where: { $0.id == subjectID }) {
            subjects[subjectIndex].notes.remove(at: noteIndex)
            // Touch the subject to mark it as modified
            subjects[subjectIndex].touch()
            scheduleSave()
        } else {
            print("📊 Error: Subject not found for deleting note")
        }
    }
    
    deinit {
        print("📊 DataManager deinitializing")
        NotificationCenter.default.removeObserver(self)
        saveDataImmediately()
    }
}
