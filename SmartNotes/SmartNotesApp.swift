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
    
    // Set to true to enter debug mode
    private let useDebugMode = false
    
    var body: some Scene {
        WindowGroup {
                // Normal app flow with debug button overlay
                MainView()
                    .environmentObject(dataManager)
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    // This would normally trigger showing the debug mode
                                    // but we'll implement that separately
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

