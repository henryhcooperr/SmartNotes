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
            ResolutionManager.shared.resolutionStrategy = .performance
            print("🚀 Performance mode enabled - using higher resolution")
        } else {
            // Use more conservative resolution when not in performance mode
            ResolutionManager.shared.resolutionStrategy = .adaptive
            print("🚀 Performance mode disabled - using standard resolution")
        }
    }
    
    // MARK: - Drawing Resolution (Legacy)
    
    /// The global resolution scale factor for all canvas-related operations.
    /// DEPRECATED: Use ResolutionManager.shared.resolutionScaleFactor instead
    /// This property is maintained for backward compatibility.
    @available(*, deprecated, message: "Use ResolutionManager.shared.resolutionScaleFactor instead")
    static let baseResolutionScaleFactor: CGFloat = 2.0
    
    /// DEPRECATED: Use ResolutionManager.shared.resolutionScaleFactor instead
    /// This property is maintained for backward compatibility.
    @available(*, deprecated, message: "Use ResolutionManager.shared.resolutionScaleFactor instead")
    static var resolutionScaleFactor: CGFloat {
        get {
            return ResolutionManager.shared.resolutionScaleFactor
        }
        set {
            // Forward to the resolution manager
            ResolutionManager.shared.setResolutionScaleFactor(newValue)
        }
    }
    
    // MARK: - Canvas Dimensions (Legacy)
    
    /// The standard page size for a single page in points (72 points per inch)
    /// DEPRECATED: Use ResolutionManager.shared.standardPageSize instead
    @available(*, deprecated, message: "Use ResolutionManager.shared.standardPageSize instead")
    static let standardPageSize = CGSize(width: 612, height: 792)
    
    /// The scaled page size after applying the resolution factor
    /// DEPRECATED: Use ResolutionManager.shared.scaledPageSize instead
    @available(*, deprecated, message: "Use ResolutionManager.shared.scaledPageSize instead")
    static var scaledPageSize: CGSize {
        return ResolutionManager.shared.scaledPageSize
    }
    
    // MARK: - Zoom Settings (Legacy)
    
    /// The minimum zoom scale for scroll views, adjusted for resolution factor
    /// DEPRECATED: Use ResolutionManager.shared.minimumZoomScale instead
    @available(*, deprecated, message: "Use ResolutionManager.shared.minimumZoomScale instead")
    static var minimumZoomScale: CGFloat {
        return ResolutionManager.shared.minimumZoomScale
    }
    
    /// The maximum zoom scale for scroll views, adjusted for resolution factor
    /// DEPRECATED: Use ResolutionManager.shared.maximumZoomScale instead
    @available(*, deprecated, message: "Use ResolutionManager.shared.maximumZoomScale instead")
    static var maximumZoomScale: CGFloat {
        return ResolutionManager.shared.maximumZoomScale
    }
    
    /// The default initial zoom scale, adjusted to maintain the same view size
    /// DEPRECATED: Use ResolutionManager.shared.defaultZoomScale instead
    @available(*, deprecated, message: "Use ResolutionManager.shared.defaultZoomScale instead")
    static var defaultZoomScale: CGFloat {
        return ResolutionManager.shared.defaultZoomScale
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
        
        // Reset resolution to default
        ResolutionManager.shared.resetToDefaultResolution()
        
        // Ensure performance monitoring is disabled
        PerformanceMonitor.shared.setMonitoringEnabled(false)
        
        print("🧹 All debug settings have been reset")
    }
} 
