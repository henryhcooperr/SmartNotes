// 
//  SaveMiddleware.swift
//  SmartNotes
//
//  Created on 6/12/25.
//
//  This file defines the SaveMiddleware, which is responsible for
//  persisting state changes to UserDefaults. It debounces save operations
//  to improve performance and ensures data is saved when the app
//  is backgrounded or terminated.
//

import Foundation
import UIKit

/// Middleware for saving state changes to UserDefaults
class SaveMiddleware: NSObject {
    /// DataManager used for saving data
    private let dataManager: DataManager
    
    /// Timer for debouncing save operations
    private var saveDebounceTimer: Timer?
    
    /// Whether a save is currently in progress
    private var isSaving = false
    
    /// Whether a save is needed after the current save completes
    private var pendingSaveNeeded = false
    
    /// Debounce interval in seconds
    private let debounceInterval: TimeInterval = 3.0
    
    /// Current app state
    private var currentState: AppState?
    
    /// Creates a new SaveMiddleware with the given DataManager
    /// - Parameter dataManager: The DataManager to use for saving data
    init(dataManager: DataManager) {
        self.dataManager = dataManager
        super.init()
        setupLifecycleObservers()
    }
    
    /// Set up observers for app lifecycle events
    private func setupLifecycleObservers() {
        // Register for app lifecycle notifications to ensure data is saved
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveImmediately),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveImmediately),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Creates a middleware function for the EventStore
    /// - Returns: A middleware function that handles saving state changes
    func middleware() -> Middleware<AppState> {
        return { [weak self] state, action in
            // Store the current state for use in saveImmediately
            self?.currentState = state
            
            // Determine if we should save based on the action type
            if self?.shouldSave(for: action) == true {
                self?.scheduleSave(with: state)
            }
        }
    }
    
    /// Schedules a save operation with debouncing
    /// - Parameter state: The state to save
    private func scheduleSave(with state: AppState) {
        // If already saving, mark that another save is needed
        if isSaving {
            pendingSaveNeeded = true
            return
        }
        
        print("💾 Scheduling save with \(debounceInterval)-second debounce")
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.save(state)
        }
    }
    
    /// Save the state to UserDefaults
    /// - Parameter state: The state to save
    private func save(_ state: AppState) {
        print("💾 Saving state to UserDefaults")
        isSaving = true
        
        // Update the DataManager's subjects with the state's subjects
        dataManager.subjects = state.contentState.subjects
        
        // Save the data using the DataManager
        dataManager.saveData()
        
        isSaving = false
        
        // If another save was requested while saving, schedule another save
        if pendingSaveNeeded {
            pendingSaveNeeded = false
            scheduleSave(with: state)
        }
    }
    
    /// Objective-C compatible method to handle app lifecycle events
    /// This method is called when the app is backgrounded or terminated
    @objc private func saveImmediately() {
        print("💾 Save immediately notification received")
        saveDebounceTimer?.invalidate()
        
        // Use the current state if available
        if let state = currentState {
            save(state)
        } else {
            print("⚠️ No state available to save")
            // Fallback to just save whatever is in the DataManager
            dataManager.saveData()
        }
    }
    
    /// Determines if the given action should trigger a save
    /// - Parameter action: The action to check
    /// - Returns: Whether the action should trigger a save
    private func shouldSave(for action: Action) -> Bool {
        // Save for actions that modify content
        switch action {
        case is SubjectAction, is NoteAction, is PageAction, is TemplateAction:
            return true
        default:
            return false
        }
    }
    
    /// Clean up resources when the middleware is deallocated
    deinit {
        NotificationCenter.default.removeObserver(self)
        saveDebounceTimer?.invalidate()
    }
} 