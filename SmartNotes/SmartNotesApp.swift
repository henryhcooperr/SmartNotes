//
//  SmartNotesApp.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//

import SwiftUI

@main
struct SmartNotesApp: App {
    // Create a shared instance of DataManager that will be used throughout the app
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(dataManager) // Make dataManager available to all views
        }
    }
}

// Main view that uses the DataManager
struct MainView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        SubjectsSplitView(subjects: $dataManager.subjects) { subject in
            // This is the onChange handler that will be passed to SubjectsSplitView
            dataManager.updateSubject(subject)
            dataManager.saveData()
        }
    }
}
