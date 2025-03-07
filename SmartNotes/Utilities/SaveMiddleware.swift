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
//  DEPRECATED: This file has been replaced by repositories and use cases in the DDD architecture.
//  Please use the repository implementations in Core/Infrastructure/Persistence instead.
//

import Foundation
import UIKit
import Combine

/// Middleware that handles saving state changes to persistent storage
class SaveMiddleware {
    private var dataManager: DataManager
    private var debounceTimer: Timer?
    private let debounceTime: TimeInterval = 3.0 // 3 seconds debounce
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
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
        
        // MIGRATION NOTE: Direct DataManager usage will be phased out when migration is complete.
        // This is currently needed for backward compatibility until all components use the EventStore.
        dataManager.subjects = state.contentState.subjects
        dataManager.saveData()
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
} 