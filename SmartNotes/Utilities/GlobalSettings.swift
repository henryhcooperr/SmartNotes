//
//  GlobalSettings.swift
//  SmartNotes
//
//  Created by Henry Cooper
//
//  This file contains global settings and constants for the entire app.
//  Key responsibilities:
//    - Providing a central location for app-wide configuration values
//    - Making configuration values accessible throughout the app
//    - Containing the resolution scale factor for high-quality drawing
//

import SwiftUI
import Foundation
import CoreGraphics

// MARK: - Global Settings
class GlobalSettings {
    // MARK: - Debug Settings
    
    /// Global debug mode setting that controls visibility of debugging tools
    /// and level of console output throughout the app
    private static var _debugModeEnabled: Bool = false
    static var debugModeEnabled: Bool {
        get {
            // Load from UserDefaults if needed
            if !_hasLoadedDebugSetting {
                _debugModeEnabled = UserDefaults.standard.bool(forKey: "debugModeEnabled")
                _hasLoadedDebugSetting = true
            }
            return _debugModeEnabled
        }
        set {
            if _debugModeEnabled != newValue {
                _debugModeEnabled = newValue
                UserDefaults.standard.set(newValue, forKey: "debugModeEnabled")
                
                // Notify observers
                NotificationCenter.default.post(
                    name: NSNotification.Name("DebugModeChanged"),
                    object: newValue
                )
                
                // When debug mode changes, update related systems
                updateDebugSystems()
            }
        }
    }
    
    /// Controls whether performance mode is enabled
    /// This is separate from debug mode and only affects performance optimizations
    private static var _performanceModeEnabled: Bool = false
    static var performanceModeEnabled: Bool {
        get {
            // Load from UserDefaults if not initialized
            if !_hasLoadedPerformanceModeSetting {
                _performanceModeEnabled = UserDefaults.standard.bool(forKey: "performanceModeEnabled")
                _hasLoadedPerformanceModeSetting = true
            }
            return _performanceModeEnabled
        }
        set {
            if _performanceModeEnabled != newValue {
                _performanceModeEnabled = newValue
                UserDefaults.standard.set(newValue, forKey: "performanceModeEnabled")
                
                // Notify observers about the change
                NotificationCenter.default.post(
                    name: NSNotification.Name("PerformanceModeChanged"),
                    object: newValue
                )
                
                // Apply performance mode changes
                updatePerformanceSettings()
            }
        }
    }
    
    /// Tracks if we've loaded performance mode setting from storage
    private static var _hasLoadedPerformanceModeSetting: Bool = false
    
    /// Tracks if we've loaded debug setting from storage
    private static var _hasLoadedDebugSetting: Bool = false
    
    /// Updates all debug-related systems when debug mode changes
    private static func updateDebugSystems() {
        // Update performance monitoring based on debug mode
        PerformanceMonitor.shared.setMonitoringEnabled(_debugModeEnabled)
        
        // Reset template system when debug mode is toggled
        if _debugModeEnabled {
            // Clear template cache when entering debug mode
            TemplateRenderer.clearTemplateCache()
        }
        
        // Log debug mode change
        if _debugModeEnabled {
            print("🐞 Debug mode enabled")
        } else {
            print("🐞 Debug mode disabled")
        }
    }
    
    /// Updates performance-related settings when performance mode changes
    private static func updatePerformanceSettings() {
        if _performanceModeEnabled {
            // Higher resolution in performance mode
            if _dynamicResolutionFactor == nil {
                _dynamicResolutionFactor = baseResolutionScaleFactor
            }
            print("🚀 Performance mode enabled - using higher resolution")
        } else {
            // Use a more conservative resolution when not in performance mode
            _dynamicResolutionFactor = 2.0
            print("🚀 Performance mode disabled - using standard resolution")
        }
    }
    
    // MARK: - Drawing Resolution
    
    /// The global resolution scale factor for all canvas-related operations.
    /// Increasing this value will improve drawing quality at higher zoom levels
    /// but may impact performance on lower-end devices.
    ///
    /// Values:
    /// - 1.0: Standard resolution (default before enhancement)
    /// - 2.0: Double resolution (good balance of quality and performance)
    /// - 3.0: Triple resolution (high quality but may affect performance)
    static let baseResolutionScaleFactor: CGFloat = 2.0
    
    /// Dynamic resolution factor that adjusts based on device capabilities and memory pressure
    private static var _dynamicResolutionFactor: CGFloat? = nil
    static var resolutionScaleFactor: CGFloat {
        get {
            // If we haven't set the dynamic factor yet, initialize it
            if _dynamicResolutionFactor == nil {
                _dynamicResolutionFactor = calculateOptimalResolutionFactor()
                
                // Start monitoring for memory pressure
                startMemoryPressureMonitoring()
            }
            return _dynamicResolutionFactor ?? baseResolutionScaleFactor
        }
        set {
            _dynamicResolutionFactor = newValue
        }
    }
    
    // MARK: - Memory Management
    
    /// Tracks if we're under memory pressure
    private static var isUnderMemoryPressure = false
    
    /// Calculate the optimal resolution factor based on device capabilities
    private static func calculateOptimalResolutionFactor() -> CGFloat {
        let device = UIDevice.current
        let processorCount = ProcessInfo.processInfo.processorCount
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Memory in GB (approximate)
        let memoryInGB = Double(totalMemory) / 1_000_000_000.0
        
        if memoryInGB >= 6.0 && processorCount >= 6 {
            // High-end devices (iPhone 13 Pro, iPad Pro, etc.)
            return baseResolutionScaleFactor
        } else if memoryInGB >= 4.0 && processorCount >= 4 {
            // Mid-range devices
            return min(baseResolutionScaleFactor, 2.5)
        } else {
            // Lower-end or older devices
            return min(baseResolutionScaleFactor, 2.0)
        }
    }
    
    /// Start monitoring for memory pressure notifications
    private static func startMemoryPressureMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleMemoryPressure()
        }
    }
    
    /// Handle memory pressure by reducing resolution temporarily
    private static func handleMemoryPressure() {
        print("⚠️ Memory warning received - reducing resolution temporarily")
        
        // Already under memory pressure
        if isUnderMemoryPressure {
            return
        }
        
        // Mark that we're under memory pressure
        isUnderMemoryPressure = true
        
        // Store the original resolution for restoration later
        let originalResolution = _dynamicResolutionFactor ?? baseResolutionScaleFactor
        
        // Reduce resolution temporarily
        _dynamicResolutionFactor = min(originalResolution, 1.5)
        
        // Clear caches
        TemplateRenderer.clearTemplateCache()
        ThumbnailGenerator.clearAllCaches()
        
        // After a delay, restore the resolution if pressure has eased
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("🔄 Attempting to restore resolution after memory pressure")
            
            // Restore resolution gradually
            _dynamicResolutionFactor = min(originalResolution, (_dynamicResolutionFactor ?? 1.0) + 0.5)
            
            // Reset flag
            isUnderMemoryPressure = false
        }
    }
    
    // MARK: - Canvas Dimensions
    
    /// The standard page size for a single page in points (72 points per inch)
    /// This is equivalent to US Letter size (8.5" x 11") at 72 DPI
    /// After scaling, this will be multiplied by the resolutionScaleFactor
    static let standardPageSize = CGSize(width: 612, height: 792)
    
    /// The scaled page size after applying the resolution factor
    static var scaledPageSize: CGSize {
        return CGSize(
            width: standardPageSize.width * resolutionScaleFactor,
            height: standardPageSize.height * resolutionScaleFactor
        )
    }
    
    // MARK: - Zoom Settings
    
    /// The minimum zoom scale for scroll views, adjusted for resolution factor
    static var minimumZoomScale: CGFloat {
        return 0.25 / resolutionScaleFactor
    }
    
    /// The maximum zoom scale for scroll views, adjusted for resolution factor
    static var maximumZoomScale: CGFloat {
        return 3.75 / resolutionScaleFactor
    }
    
    /// The default initial zoom scale, adjusted to maintain the same view size
    static var defaultZoomScale: CGFloat {
        return 1.0 / resolutionScaleFactor
    }
    
    // MARK: - Page Navigation Settings
    
    /// Controls whether the app automatically scrolls to newly detected pages during scrolling
    private static var _autoScrollToDetectedPages: Bool = false
    static var autoScrollToDetectedPages: Bool {
        get {
            // Load from UserDefaults if not initialized
            if !_hasLoadedAutoScrollSetting {
                _autoScrollToDetectedPages = UserDefaults.standard.bool(forKey: "autoScrollToDetectedPages")
                _hasLoadedAutoScrollSetting = true
            }
            return _autoScrollToDetectedPages
        }
        set {
            if _autoScrollToDetectedPages != newValue {
                _autoScrollToDetectedPages = newValue
                UserDefaults.standard.set(newValue, forKey: "autoScrollToDetectedPages")
                
                // Notify observers about the change
                NotificationCenter.default.post(
                    name: NSNotification.Name("AutoScrollSettingChanged"),
                    object: newValue
                )
            }
        }
    }
    
    /// Tracks if we've loaded auto-scroll setting from storage
    private static var _hasLoadedAutoScrollSetting: Bool = false
    
    /// Force reset all debug and performance related settings
    /// Call this at app startup to ensure a clean state
    static func forceResetAllDebugSettings() {
        // Reset internal state
        _debugModeEnabled = false
        _performanceModeEnabled = false
        _hasLoadedDebugSetting = true
        _hasLoadedPerformanceModeSetting = true
        
        // Reset UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "debugModeEnabled")
        defaults.removeObject(forKey: "performanceModeEnabled")
        defaults.removeObject(forKey: "showPerformanceStats")
        defaults.set(false, forKey: "debugModeEnabled")
        defaults.set(false, forKey: "performanceModeEnabled")
        defaults.set(false, forKey: "showPerformanceStats")
        
        // Ensure performance monitoring is disabled
        PerformanceMonitor.shared.setMonitoringEnabled(false)
        
        print("🧹 All debug settings have been reset")
    }
} 
