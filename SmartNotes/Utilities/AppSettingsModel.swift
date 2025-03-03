//
//  AppSettingsModel.swift
//  SmartNotes
//
//  This file contains app-wide settings and preferences that can be
//  modified by the user and persisted between app launches.
//

import SwiftUI
import Combine

class AppSettingsModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether to show performance statistics in debug overlay
    @Published var showPerformanceStats: Bool = false {
        didSet {
            saveSettings()
            // Update the performance monitor
            PerformanceMonitor.shared.setMonitoringEnabled(showPerformanceStats)
        }
    }
    
    /// Whether to use adaptive resolution for optimal performance
    @Published var useAdaptiveResolution: Bool = true {
        didSet {
            saveSettings()
            updateAdaptiveResolution()
        }
    }
    
    /// User-selected resolution factor when not using adaptive resolution
    @Published var userResolutionFactor: CGFloat = 2.0 {
        didSet {
            saveSettings()
            updateUserResolution()
        }
    }
    
    /// Whether to use template caching for performance
    @Published var useTemplateCaching: Bool = true {
        didSet {
            saveSettings()
            if !useTemplateCaching {
                TemplateRenderer.clearTemplateCache()
            }
        }
    }
    
    /// Whether to optimize during scrolling/zooming
    @Published var optimizeDuringInteraction: Bool = true {
        didSet {
            saveSettings()
        }
    }
    
    // MARK: - Keys for UserDefaults
    
    private let showPerformanceStatsKey = "showPerformanceStats"
    private let useAdaptiveResolutionKey = "useAdaptiveResolution"
    private let userResolutionFactorKey = "userResolutionFactor"
    private let useTemplateCachingKey = "useTemplateCaching"
    private let optimizeDuringInteractionKey = "optimizeDuringInteraction"
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        
        // Check if debug mode is enabled
        if GlobalSettings.debugModeEnabled {
            // If debug mode is on, respect the saved setting
            PerformanceMonitor.shared.setMonitoringEnabled(showPerformanceStats)
        } else {
            // If debug mode is off, ensure monitoring is disabled
            PerformanceMonitor.shared.setMonitoringEnabled(false)
            
            // If stats were enabled but debug mode is off, turn them off
            if showPerformanceStats {
                showPerformanceStats = false
            }
        }
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        showPerformanceStats = defaults.bool(forKey: showPerformanceStatsKey)
        
        if defaults.object(forKey: useAdaptiveResolutionKey) != nil {
            useAdaptiveResolution = defaults.bool(forKey: useAdaptiveResolutionKey)
        }
        
        if let factor = defaults.object(forKey: userResolutionFactorKey) as? Double {
            userResolutionFactor = CGFloat(factor)
        }
        
        if defaults.object(forKey: useTemplateCachingKey) != nil {
            useTemplateCaching = defaults.bool(forKey: useTemplateCachingKey)
        }
        
        if defaults.object(forKey: optimizeDuringInteractionKey) != nil {
            optimizeDuringInteraction = defaults.bool(forKey: optimizeDuringInteractionKey)
        }
        
        // Apply initial settings
        updateResolutionSettings()
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(showPerformanceStats, forKey: showPerformanceStatsKey)
        defaults.set(useAdaptiveResolution, forKey: useAdaptiveResolutionKey)
        defaults.set(Double(userResolutionFactor), forKey: userResolutionFactorKey)
        defaults.set(useTemplateCaching, forKey: useTemplateCachingKey)
        defaults.set(optimizeDuringInteraction, forKey: optimizeDuringInteractionKey)
    }
    
    // MARK: - Resolution Management
    
    private func updateResolutionSettings() {
        if useAdaptiveResolution {
            updateAdaptiveResolution()
        } else {
            updateUserResolution()
        }
    }
    
    private func updateAdaptiveResolution() {
        if useAdaptiveResolution {
            // Reset to allow GlobalSettings to calculate best factor
            GlobalSettings.resolutionScaleFactor = GlobalSettings.baseResolutionScaleFactor
        }
    }
    
    private func updateUserResolution() {
        if !useAdaptiveResolution {
            // Set to user-specified value
            GlobalSettings.resolutionScaleFactor = userResolutionFactor
        }
    }
    
    // MARK: - Performance Management
    
    /// Toggle performance monitoring on/off
    func togglePerformanceMonitoring() {
        showPerformanceStats.toggle()
        PerformanceMonitor.shared.setMonitoringEnabled(showPerformanceStats)
    }
    
    /// Clear all caches to free memory
    func clearAllCaches() {
        TemplateRenderer.clearTemplateCache()
        ThumbnailGenerator.clearAllCaches()
    }
} 