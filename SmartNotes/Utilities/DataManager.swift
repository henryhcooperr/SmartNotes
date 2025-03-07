//
//  DataManager.swift
//  SmartNotes
//
//  Created on 2/25/25.
//
//  This file manages data persistence for the application.
//  Key responsibilities:
//    - Storing and retrieving subjects and notes using UserDefaults
//    - Providing CRUD operations for subjects and notes
//    - Observing app lifecycle to ensure data is saved
//    - Debouncing saves to improve performance
//    - Creating default subjects when no data exists
//
//  This is the central data handling component that connects
//  the UI with persistent storage.
//

import SwiftUI
import Combine
import UIKit
import PencilKit

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
        do {
            if let data = UserDefaults.standard.data(forKey: saveKey) {
                var decoded = try JSONDecoder().decode([Subject].self, from: data)
                print("📊 Successfully decoded \(decoded.count) subjects")

                for subjectIndex in decoded.indices {
                    for noteIndex in decoded[subjectIndex].notes.indices {
                        let note = decoded[subjectIndex].notes[noteIndex]

                        // Validate drawing data if needed
                        if !note.drawingData.isEmpty {
                            do {
                                _ = try PKDrawing(data: note.drawingData)
                                print("✅ Valid drawing data for note: \(note.id)")
                            } catch {
                                print("❌ Invalid drawing data for note: \(note.id)")
                            }
                        }
                        
                        // Migrate single-drawing to multi-page if needed
                        if note.pages.isEmpty && !note.drawingData.isEmpty {
                            print("📝 Migrating note \(note.id) to multi-page structure")
                            let newPage = Page(
                                drawingData: note.drawingData,
                                template: nil,
                                pageNumber: 1
                            )
                            decoded[subjectIndex].notes[noteIndex].pages = [newPage]
                            
                            // Optional: clear the old single-drawing data so
                            // we don't repeatedly migrate
                            decoded[subjectIndex].notes[noteIndex].drawingData = Data()
                        }
                    }
                }

                // Finally, assign the migrated array back to your published subjects
                self.subjects = decoded
            } else {
                print("📊 No data found in UserDefaults")
                setupDefaultSubjects()
            }
        } catch {
            print("📊 Decoding error: \(error)")
            setupDefaultSubjects()
        }
    }

    private func setupDefaultSubjects() {
        print("📊 Creating default subjects")
        self.subjects = [
            Subject(name: "Math", notes: [], colorName: "blue"),
            Subject(name: "History", notes: [], colorName: "red"),
            Subject(name: "Science", notes: [], colorName: "green")
        ]
    }

    func saveData() {
        print("📊 DataManager saving data with \(subjects.count) subjects")
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted // Optional: for debugging
                let encoded = try encoder.encode(self.subjects)
                
                DispatchQueue.main.async {
                    UserDefaults.standard.set(encoded, forKey: self.saveKey)
                    print("📊 Data saved successfully to UserDefaults")
                }
            } catch {
                print("📊 Failed to encode subjects: \(error)")
            }
        }
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
    
    // New method for immediate template updates
    func updateNoteTemplateAndSaveImmediately(in subjectID: UUID, noteID: UUID, template: CanvasTemplate) {
        print("📊 Immediately updating template for note: \(noteID) in subject: \(subjectID)")
        print("📊 New template type: \(template.type.rawValue), spacing: \(template.spacing), color: \(template.colorHex)")
        if let subjectIndex = subjects.firstIndex(where: { $0.id == subjectID }),
           let noteIndex = subjects[subjectIndex].notes.firstIndex(where: { $0.id == noteID }) {
            print("📊 Found subject at index \(subjectIndex), note at index \(noteIndex)")
            
            // Log the current template before changing
            if let currentTemplate = subjects[subjectIndex].notes[noteIndex].noteTemplate {
                print("📊 Changing template from \(currentTemplate.type.rawValue) to \(template.type.rawValue)")
            } else {
                print("📊 Setting initial template to \(template.type.rawValue)")
            }
            
            // Update the template
            subjects[subjectIndex].notes[noteIndex].noteTemplate = template
            subjects[subjectIndex].touch()
            
            print("📊 Forcing immediate save...")
            saveDataImmediately() // Force immediate save
            print("📊 Save completed")
            
            // Verify the template was updated correctly
            if let savedTemplate = subjects[subjectIndex].notes[noteIndex].noteTemplate {
                print("📊 Verified template is now: \(savedTemplate.type.rawValue)")
            } else {
                print("📊 ERROR: Template is nil after save!")
            }
        } else {
            print("📊 Error: Subject or Note not found for template update")
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
    func createNewNote(title: String, in subjectID: UUID) -> Note {
        print("📊 Creating new note with title: \(title)")
        
        // Create a new note with a single empty page
        let newPage = Page(
            drawingData: Data(),
            template: nil,
            pageNumber: 1
        )
        
        let newNote = Note(
            title: title,
            drawingData: Data(),
            pages: [newPage]
        )
        
        // Add it to the appropriate subject
        addNote(to: subjectID, note: newNote)
        
        print("📊 New note created with ID: \(newNote.id), includes 1 empty page")
        return newNote
    }
}
