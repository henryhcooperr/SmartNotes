// 
//  SaveMiddleware.swift
//  SmartNotes
//
//  Created on 6/12/25.
//  Updated on 5/6/25 to remove DataManager dependencies
//
//  This file defines the SaveMiddleware, which is responsible for
//  persisting state changes to the file system. It debounces save operations
//  to improve performance and ensures data is saved when the app
//  is backgrounded or terminated.
//
//  DEPRECATED: This file has been replaced by repositories and use cases in the DDD architecture.
//  Please use the repository implementations in Core/Infrastructure/Persistence instead.
//

import Foundation
import UIKit
import Combine

/// Middleware that handles saving state changes to persistent storage
class SaveMiddleware {
    private var debounceTimer: Timer?
    private let debounceTime: TimeInterval = 3.0 // 3 seconds debounce
    private let fileManager = FileManager.default
    private let eventBus = EventBus.shared
    
    // File paths
    private let saveDirectory: URL
    private let subjectsFilePath: URL
    private let settingsFilePath: URL
    
    // Save events
    struct SaveCompletedEvent: Event {
        static var description: String = "State has been saved to persistent storage"
        let timestamp: Date
        let bytesSaved: Int
    }
    
    struct SaveFailedEvent: Event {
        static var description: String = "Failed to save state to persistent storage"
        let timestamp: Date
        let error: Error
    }
    
    init() {
        // Setup save directories
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        saveDirectory = documentsDirectory.appendingPathComponent("SmartNotes", isDirectory: true)
        subjectsFilePath = saveDirectory.appendingPathComponent("subjects.json")
        settingsFilePath = saveDirectory.appendingPathComponent("settings.json")
        
        // Create save directory if it doesn't exist
        try? fileManager.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        
        print("💾 SaveMiddleware: Initialized with save directory: \(saveDirectory.path)")
    }
    
    /// The middleware function that will be called for each action
    func middleware(state: AppState, action: Action) {
        // Only process actions that affect content state
        let shouldSave = shouldSaveForAction(action)
        
        if shouldSave {
            print("🔄 SaveMiddleware: Scheduling save for action: \(action.description)")
            scheduleSave(state: state)
        }
    }
    
    /// Schedule a save with debouncing
    private func scheduleSave(state: AppState) {
        // Cancel any existing timer
        debounceTimer?.invalidate()
        
        // Schedule a new save
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceTime, repeats: false) { [weak self] _ in
            self?.performSave(state: state)
        }
    }
    
    /// Perform the actual save operation
    private func performSave(state: AppState) {
        print("💾 SaveMiddleware: Performing save...")
        
        // Create JSON encoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            // Save subjects data
            let subjectsData = try encoder.encode(state.contentState.subjects)
            try subjectsData.write(to: subjectsFilePath)
            
            // Save settings separately
            let settingsData = try encoder.encode(state.settingsState)
            try settingsData.write(to: settingsFilePath)
            
            // Calculate total bytes saved
            let totalBytesSaved = subjectsData.count + settingsData.count
            
            // Publish save completed event
            eventBus.publish(SaveCompletedEvent(
                timestamp: Date(),
                bytesSaved: totalBytesSaved
            ))
            
            print("💾 SaveMiddleware: Save completed (\(totalBytesSaved) bytes)")
        } catch {
            print("❌ SaveMiddleware: Error saving data: \(error.localizedDescription)")
            
            // Publish save failed event
            eventBus.publish(SaveFailedEvent(
                timestamp: Date(),
                error: error
            ))
        }
    }
    
    /// Force an immediate save without debouncing
    func forceSave(state: AppState) {
        print("💾 SaveMiddleware: Forcing immediate save...")
        debounceTimer?.invalidate()
        performSave(state: state)
    }
    
    /// Determine if the action should trigger a save
    private func shouldSaveForAction(_ action: Action) -> Bool {
        switch action {
        case is SubjectAction, is NoteAction, is PageAction, is TemplateAction:
            return true
            
        case let settingsAction as SettingsAction:
            // Only save settings that should be persisted
            switch settingsAction {
            case .updateFingerDrawingSetting, .updateAutoScrollSetting, .setDefaultTemplate:
                return true
            default:
                return false
            }
            
        default:
            return false
        }
    }
    
    /// Load saved data from persistent storage
    func loadSavedData() -> (subjects: [Subject], settings: SettingsState)? {
        let decoder = JSONDecoder()
        
        do {
            // Load subjects
            var subjects: [Subject] = []
            if fileManager.fileExists(atPath: subjectsFilePath.path) {
                let subjectsData = try Data(contentsOf: subjectsFilePath)
                subjects = try decoder.decode([Subject].self, from: subjectsData)
            }
            
            // Load settings
            var settings = SettingsState()
            if fileManager.fileExists(atPath: settingsFilePath.path) {
                let settingsData = try Data(contentsOf: settingsFilePath)
                settings = try decoder.decode(SettingsState.self, from: settingsData)
            }
            
            return (subjects: subjects, settings: settings)
        } catch {
            print("❌ SaveMiddleware: Error loading data: \(error.localizedDescription)")
            return nil
        }
    }
} 