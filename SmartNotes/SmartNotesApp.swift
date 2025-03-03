//
//  SmartNotesApp.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
//  This is the application entry point that sets up the environment.
//  Key responsibilities:
//    - Creating the DataManager shared instance
//    - Setting up the MainView as the root view
//    - Passing the DataManager through the environment
//
//  This file also contains the MainView, which integrates the
//  SubjectsSplitView with the app's data layer.
//
import SwiftUI

// Make sure we import our utilities
import PencilKit

@main
struct SmartNotesApp: App {
    // Create a shared instance of DataManager that will be used throughout the app
    @StateObject private var dataManager = DataManager()
    
    // Initialize AppSettings for app-wide access to performance settings
    @StateObject private var appSettings = AppSettingsModel()
    
    // Track whether the performance settings are visible
    @State private var showPerformanceSettings = false
    
    // Use an initialization function to setup the app
    init() {
        // Print out our resolution settings for debugging
        print("📏 Resolution scale factor: \(GlobalSettings.resolutionScaleFactor)")
        print("📏 Standard page size: \(GlobalSettings.standardPageSize)")
        print("📏 Scaled page size: \(GlobalSettings.scaledPageSize)")
        print("📏 Minimum zoom scale: \(GlobalSettings.minimumZoomScale)")
        print("📏 Maximum zoom scale: \(GlobalSettings.maximumZoomScale)")
        
        // Enable performance monitoring based on debug mode
        PerformanceMonitor.shared.setMonitoringEnabled(GlobalSettings.debugModeEnabled)
        
        // Use performance monitor to measure app launch time
        PerformanceMonitor.shared.startOperation("App launch")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                MainView()
                    .environmentObject(dataManager)
                    .environmentObject(appSettings)
                    .onAppear {
                        // Force clear the thumbnail cache on app launch
                        ThumbnailGenerator.clearCache()
                        // Mark the end of app launch
                        PerformanceMonitor.shared.endOperation("App launch")
                    }
                    // Add a hidden gesture to toggle debug mode (long press with two fingers)
                    .onLongPressGesture(minimumDuration: 2, maximumDistance: 50, pressing: nil) {
                        // Toggle debug mode
                        GlobalSettings.debugModeEnabled.toggle()
                        
                        // Update app settings if debug mode changed
                        appSettings.showPerformanceStats = GlobalSettings.debugModeEnabled
                    }
                
                // Only show debug UI elements if debug mode is enabled
                if GlobalSettings.debugModeEnabled {
                    // Performance stats overlay
                    if appSettings.showPerformanceStats {
                        VStack {
                            PerformanceStatsOverlay()
                                .environmentObject(appSettings)
                            Spacer()
                        }
                        .zIndex(99)
                    }
                    
                    // Performance settings sheet overlay
                    if showPerformanceSettings {
                        PerformanceSettingsView(isVisible: $showPerformanceSettings)
                            .environmentObject(appSettings)
                            .transition(.move(edge: .bottom))
                            .zIndex(100)
                    }
                    
                    // Debug button overlay
                    VStack {
                        Spacer()
                        HStack {
                            // Quick toggle for performance monitoring
                            Button {
                                appSettings.showPerformanceStats.toggle()
                                PerformanceMonitor.shared.setMonitoringEnabled(appSettings.showPerformanceStats)
                            } label: {
                                Image(systemName: appSettings.showPerformanceStats ? "gauge.badge.minus" : "gauge.badge.plus")
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding()
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    showPerformanceSettings.toggle()
                                }
                            } label: {
                                Text("PERFORMANCE")
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding()
                        }
                    }
                    .zIndex(101)
                }
            }
        }
    }
}

// Main view that uses the DataManager
struct MainView: View {
    @EnvironmentObject var dataManager: DataManager
    
    // Add state to manage the currently selected note and subject
    @State private var selectedNote: Note? = nil
    @State private var selectedSubjectID: UUID? = nil
    @State private var isNoteDetailPresented = false
    
    var body: some View {
        ZStack {
            // Show SubjectsSplitView as primary content
            SubjectsSplitView(
                subjects: $dataManager.subjects,
                onNoteSelected: { note, subjectID in
                    // When a note is selected, capture it and show modal
                    selectedNote = note
                    selectedSubjectID = subjectID
                    isNoteDetailPresented = true
                }
            ) { subject in
                dataManager.updateSubject(subject)
                dataManager.saveData()
            }
            
            // Full-screen modal for note detail
            if let note = selectedNote, let subjectID = selectedSubjectID, isNoteDetailPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                // Present NoteDetailView as a full screen modal
                NoteDetailView(
                    note: Binding(
                        get: { note },
                        set: { newNote in
                            // Update the note in the dataManager
                            if let subjectIndex = dataManager.subjects.firstIndex(where: { $0.id == subjectID }),
                               let noteIndex = dataManager.subjects[subjectIndex].notes.firstIndex(where: { $0.id == note.id }) {
                                dataManager.subjects[subjectIndex].notes[noteIndex] = newNote
                                dataManager.saveData()
                            }
                        }
                    ),
                    subjectID: subjectID,
                    onDismiss: {
                        isNoteDetailPresented = false
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(1) // Ensure it's above other content
            }
        }
        .animation(.easeInOut, value: isNoteDetailPresented)
    }
}

// Performance settings view
struct PerformanceSettingsView: View {
    @EnvironmentObject var appSettings: AppSettingsModel
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Performance Settings")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
            }
            .padding(.bottom)
            
            // Resolution settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Resolution").font(.subheadline).bold()
                
                Toggle("Adaptive Resolution", isOn: $appSettings.useAdaptiveResolution)
                
                if !appSettings.useAdaptiveResolution {
                    VStack(alignment: .leading) {
                        Text("Resolution Scale: \(String(format: "%.1f", appSettings.userResolutionFactor))x")
                        
                        Slider(value: $appSettings.userResolutionFactor, in: 1.0...3.0, step: 0.5)
                    }
                }
                
                Text("Current active resolution: \(String(format: "%.1f", GlobalSettings.resolutionScaleFactor))x")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical)
            
            // Performance optimization settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Optimizations").font(.subheadline).bold()
                
                Toggle("Template Caching", isOn: $appSettings.useTemplateCaching)
                Toggle("Optimize During Scrolling", isOn: $appSettings.optimizeDuringInteraction)
                Toggle("Show Performance Stats", isOn: $appSettings.showPerformanceStats)
            }
            .padding(.vertical)
            
            // Actions
            VStack {
                Button(action: { appSettings.clearAllCaches() }) {
                    Text("Clear All Caches")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 450)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }
}

