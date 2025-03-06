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
    
    /// Whether to enable centralized resource management
    @Published var useCentralizedResourceManagement: Bool = true {
        didSet {
            saveSettings()
            UserDefaults.standard.set(useCentralizedResourceManagement, forKey: useCentralizedResourceManagementKey)
            
            // Clear all caches if turning this off to ensure clean state
            if !useCentralizedResourceManagement {
                ResourceManager.shared.removeAllResources(ofType: .noteThumbnail)
                ResourceManager.shared.removeAllResources(ofType: .pageThumbnail)
                ResourceManager.shared.removeAllResources(ofType: .template)
                ResourceManager.shared.removeAllResources(ofType: .custom)
            }
        }
    }
    
    // MARK: - Keys for UserDefaults
    
    private let showPerformanceStatsKey = "showPerformanceStats"
    private let useAdaptiveResolutionKey = "useAdaptiveResolution"
    private let userResolutionFactorKey = "userResolutionFactor"
    private let useTemplateCachingKey = "useTemplateCaching"
    private let optimizeDuringInteractionKey = "optimizeDuringInteraction"
    private let useCentralizedResourceManagementKey = "useCentralizedResourceManagement"
    
    // MARK: - Initialization
    
    init() {
        // Load settings from UserDefaults
        let defaults = UserDefaults.standard
        
        showPerformanceStats = defaults.bool(forKey: showPerformanceStatsKey)
        useAdaptiveResolution = defaults.bool(forKey: useAdaptiveResolutionKey)
        optimizeDuringInteraction = defaults.bool(forKey: optimizeDuringInteractionKey)
        useTemplateCaching = defaults.bool(forKey: useTemplateCachingKey)
        
        // Default to true for centralized resource management if not set
        useCentralizedResourceManagement = defaults.object(forKey: useCentralizedResourceManagementKey) != nil ? 
            defaults.bool(forKey: useCentralizedResourceManagementKey) : true
        
        // Load user resolution if available
        if let storedResolution = defaults.object(forKey: userResolutionFactorKey) as? CGFloat {
            userResolutionFactor = storedResolution
        }
        
        // Store default values if not already stored
        if defaults.object(forKey: useAdaptiveResolutionKey) == nil {
            defaults.set(true, forKey: useAdaptiveResolutionKey)
        }
        
        if defaults.object(forKey: useTemplateCachingKey) == nil {
            defaults.set(true, forKey: useTemplateCachingKey)
        }
        
        if defaults.object(forKey: optimizeDuringInteractionKey) == nil {
            defaults.set(true, forKey: optimizeDuringInteractionKey)
        }
        
        // Set template caching flag
        defaults.set(useTemplateCaching, forKey: "useTemplateCaching")
        
        // Update resolution strategy based on settings
        updateAdaptiveResolution()
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        showPerformanceStats = defaults.bool(forKey: showPerformanceStatsKey)
        
        // Sync with GlobalSettings.performanceModeEnabled
        if GlobalSettings.performanceModeEnabled && !showPerformanceStats {
            showPerformanceStats = true
        }
        
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
        defaults.set(useCentralizedResourceManagement, forKey: useCentralizedResourceManagementKey)
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
            // Use ResolutionManager to use adaptive resolution
            ResolutionManager.shared.useAdaptiveResolution()
        }
    }
    
    private func updateUserResolution() {
        if !useAdaptiveResolution {
            // Set to user-specified value using ResolutionManager
            ResolutionManager.shared.setResolutionFactor(userResolutionFactor)
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