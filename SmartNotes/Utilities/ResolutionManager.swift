//
//  ResolutionManager.swift
//  SmartNotes
//
//  Created on 5/8/25
//  Updated on 5/8/25 to integrate with EventStore architecture
//
//  This file centralizes all resolution scaling logic throughout the app.
//  Key responsibilities:
//    - Managing and adjusting resolution scale factors based on device capabilities
//    - Providing consistent resolution values to all components
//    - Monitoring device memory pressure and adjusting resolution accordingly
//    - Notifying components of resolution changes
//    - Providing utilities for scaling operations
//

import UIKit
import Foundation
import CoreGraphics

// MARK: - Resolution Events

/// Event published when resolution scale factor changes
struct ResolutionChangedEvent: Event {
    static var description: String = "Resolution scale factor changed"
    let oldFactor: CGFloat
    let newFactor: CGFloat
    let reason: String
}

/// Event published when memory pressure is detected
struct MemoryPressureEvent: Event {
    static var description: String = "System reported memory pressure"
    let timestamp: Date
    let previousResolutionFactor: CGFloat
    let newResolutionFactor: CGFloat
}

// MARK: - Resolution Change Observer Protocol

/// Protocol for components that need to respond to resolution changes
protocol ResolutionChangeObserver: AnyObject {
    /// Called when the resolution scale factor changes
    func resolutionDidChange(newResolutionFactor: CGFloat)
}

// MARK: - Resolution Strategy

/// Defines different strategies for managing resolution
enum ResolutionStrategy {
    /// Fixed resolution at a specific scale factor
    case fixed(factor: CGFloat)
    
    /// Dynamic resolution that adapts based on device capabilities
    case adaptive
    
    /// Performance-optimized resolution that prioritizes rendering quality
    case performance
    
    /// Memory-conservative resolution that prioritizes stability
    case memoryConservative
}

// MARK: - Resolution Manager

/// Centralized manager for all resolution-related settings and calculations
class ResolutionManager {
    // MARK: - Singleton Access
    
    /// Shared instance for app-wide access
    static let shared = ResolutionManager()
    
    // Private initialization prevents multiple instances
    private init() {
        // Initialize with a default value first
        _resolutionScaleFactor = 2.0
        
        // Then update the resolution based on device capabilities
        _resolutionScaleFactor = calculateOptimalResolutionFactor()
        
        // Start monitoring for memory pressure
        startMemoryPressureMonitoring()
        
        // Log initialization
        print("🔍 ResolutionManager: Initialized with scale factor \(resolutionScaleFactor)")
    }
    
    // MARK: - Properties
    
    /// Event bus for publishing events
    private let eventBus = EventBus.shared
    
    /// Subscription manager for event subscriptions
    private let subscriptionManager = SubscriptionManager()
    
    /// Base resolution scale factor (default value)
    private let baseResolutionScaleFactor: CGFloat = 3.0
    
    /// Current resolution strategy
    private var _resolutionStrategy: ResolutionStrategy = .adaptive
    var resolutionStrategy: ResolutionStrategy {
        get {
            return _resolutionStrategy
        }
        set {
            if case .fixed(let factor) = newValue {
                // Directly set the resolution factor for fixed strategy
                setResolutionScaleFactor(factor)
            }
            
            _resolutionStrategy = newValue
            
            // Recalculate based on the new strategy
            updateResolutionBasedOnStrategy()
            
            // Log strategy change
            print("🔍 ResolutionManager: Strategy changed to \(describeStrategy(newValue))")
        }
    }
    
    /// Current resolution scale factor
    private var _resolutionScaleFactor: CGFloat
    var resolutionScaleFactor: CGFloat {
        return _resolutionScaleFactor
    }
    
    /// Tracks if we're under memory pressure
    private var isUnderMemoryPressure = false
    
    /// The original resolution scale factor before memory pressure adjustment
    private var originalResolutionFactor: CGFloat?
    
    /// The page size for notes pages (US Letter: 8.5" x 11" at 72 DPI)
    internal let standardPageSize = CGSize(width: 612, height: 792)
    
    // MARK: - Observer Management
    
    /// Array of weak references to resolution change observers
    private var observers = [WeakObserver]()
    
    /// Wrapper for weak references to observers
    private class WeakObserver {
        weak var observer: ResolutionChangeObserver?
        
        init(_ observer: ResolutionChangeObserver) {
            self.observer = observer
        }
    }
    
    /// Register an observer to be notified of resolution changes
    func addObserver(_ observer: ResolutionChangeObserver) {
        // Remove the observer first if it already exists to prevent duplicates
        removeObserver(observer)
        
        // Add the observer
        observers.append(WeakObserver(observer))
        
        // Clean up any nil references
        cleanupObservers()
        
        // Log observer addition
        print("🔍 ResolutionManager: Added observer \(type(of: observer))")
    }
    
    /// Remove an observer
    func removeObserver(_ observer: ResolutionChangeObserver) {
        observers.removeAll { $0.observer === observer }
    }
    
    /// Clean up nil references in the observers array
    private func cleanupObservers() {
        observers.removeAll { $0.observer == nil }
    }
    
    /// Notify all observers of resolution change
    private func notifyObserversOfResolutionChange() {
        // Clean up nil references first
        cleanupObservers()
        
        // Notify each observer
        for weakObserver in observers {
            if let observer = weakObserver.observer {
                observer.resolutionDidChange(newResolutionFactor: resolutionScaleFactor)
            }
        }
    }
    
    // MARK: - Resolution Management
    
    /// Set a new resolution scale factor
    func setResolutionScaleFactor(_ newValue: CGFloat, reason: String = "manual") {
        // Log change
        print("🔍 ResolutionManager: Changing resolution factor from \(_resolutionScaleFactor) to \(newValue)")
        
        let oldValue = _resolutionScaleFactor
        
        // Only update if there's an actual change
        if abs(oldValue - newValue) > 0.01 {
            _resolutionScaleFactor = newValue
            
            // Notify observers of the change
            notifyObserversOfResolutionChange()
            
            // Publish event using EventBus
            eventBus.publish(ResolutionChangedEvent(
                oldFactor: oldValue,
                newFactor: newValue,
                reason: reason
            ))
            
            // For backward compatibility
            NotificationCenter.default.post(
                name: .resolutionFactorDidChange,
                object: nil,
                userInfo: [
                    "oldFactor": oldValue,
                    "newFactor": newValue
                ]
            )
        }
    }
    
    /// Update resolution based on current strategy
    func updateResolutionBasedOnStrategy() {
        // No-op if we're in fixed strategy mode
        if case .fixed = _resolutionStrategy {
            return
        }
        
        // Calculate the appropriate resolution factor
        var factor: CGFloat
        
        switch _resolutionStrategy {
        case .adaptive:
            factor = calculateOptimalResolutionFactor()
        case .performance:
            factor = max(3.0, calculateOptimalResolutionFactor())
        case .memoryConservative:
            factor = min(1.5, calculateOptimalResolutionFactor())
        case .fixed(let fixedFactor):
            factor = fixedFactor
        }
        
        // If we're under memory pressure, limit the factor
        if isUnderMemoryPressure {
            factor = min(factor, 1.5)
        }
        
        // Set the new factor
        setResolutionScaleFactor(factor, reason: "strategy")
    }
    
    /// Calculate the optimal resolution factor based on device capabilities
    private func calculateOptimalResolutionFactor() -> CGFloat {
        // Get device-specific information
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let screenScale = UIScreen.main.scale
        let deviceModel = UIDevice.current.model
        
        // Base resolution factor
        var factor: CGFloat = 2.0
        
        // Memory-based adjustments
        let memoryGB = CGFloat(totalMemory) / 1_000_000_000
        if memoryGB >= 6 {
            // High-end devices with plenty of memory
            factor = 3.0
        } else if memoryGB >= 4 {
            // Mid-range devices
            factor = 2.5
        } else if memoryGB >= 2 {
            // Lower-end devices
            factor = 2.0
        } else {
            // Very limited memory
            factor = 1.5
        }
        
        // Screen scale adjustments
        if screenScale > 2.5 {
            // Increase for high-DPI screens
            factor += 0.5
        }
        
        // iPad-specific adjustments
        if deviceModel.contains("iPad") {
            // iPads typically handle higher resolutions better
            factor += 0.25
            
            // iPad Pro enhancement
            if deviceModel.contains("iPad Pro") {
                factor += 0.25
            }
        }
        
        // Cap to reasonable bounds
        factor = min(max(factor, 1.0), 4.0)
        
        return factor
    }
    
    // MARK: - Memory Pressure Handling
    
    /// Start monitoring for memory pressure notifications
    private func startMemoryPressureMonitoring() {
        // Continue to use NotificationCenter for system notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarningNotification),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Also subscribe to SystemAction.memoryWarning events from EventStore
        subscriptionManager.subscribe(SystemAction.memoryWarning.self) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    /// Handle memory warning notification
    @objc private func handleMemoryWarningNotification() {
        handleMemoryWarning()
    }
    
    /// Common handling of memory warnings
    private func handleMemoryWarning() {
        print("⚠️ ResolutionManager: Received memory warning")
        
        // If this is the first memory warning, store the original factor
        if !isUnderMemoryPressure {
            originalResolutionFactor = resolutionScaleFactor
            isUnderMemoryPressure = true
        }
        
        // Calculate reduced resolution factor
        let reducedFactor = min(resolutionScaleFactor, 1.5)
        
        // Only update if there's an actual change
        if abs(resolutionScaleFactor - reducedFactor) > 0.01 {
            // Store the previous resolution for reporting
            let previousResolution = resolutionScaleFactor
            
            // Set the reduced factor
            setResolutionScaleFactor(reducedFactor, reason: "memory pressure")
            
            // Publish memory pressure event
            eventBus.publish(MemoryPressureEvent(
                timestamp: Date(),
                previousResolutionFactor: previousResolution,
                newResolutionFactor: reducedFactor
            ))
            
            print("⚠️ ResolutionManager: Reduced resolution factor to \(reducedFactor) due to memory pressure")
        }
        
        // Schedule recovery if possible
        scheduleMemoryPressureRecovery()
    }
    
    /// Schedule recovery from memory pressure
    private func scheduleMemoryPressureRecovery() {
        // After a delay, check if we can restore the original resolution
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, self.isUnderMemoryPressure, let originalFactor = self.originalResolutionFactor else {
                return
            }
            
            print("🔍 ResolutionManager: Attempting to recover from memory pressure")
            
            // Reset memory pressure flag
            self.isUnderMemoryPressure = false
            
            // Apply the current strategy again (which will respect the original factor)
            self.updateResolutionBasedOnStrategy()
            
            print("🔍 ResolutionManager: Recovered from memory pressure, new factor: \(self.resolutionScaleFactor)")
        }
    }
    
    // MARK: - EventStore Integration
    
    /// Configure the ResolutionManager with the EventStore
    func configure(with eventStore: EventStore) {
        print("🔍 ResolutionManager: Configuring with EventStore")
        
        // Listen for system events that might affect resolution
        subscriptionManager.subscribe(SystemAction.appDidEnterBackground.self) { [weak self] _ in
            // Reduce resolution when app is in background
            guard let self = self else { return }
            
            // Store current resolution factor
            let currentFactor = self.resolutionScaleFactor
            
            // Apply lower resolution in background
            self.setResolutionScaleFactor(1.0, reason: "background")
            
            print("🔍 ResolutionManager: Reduced resolution to 1.0 for background mode (was \(currentFactor))")
        }
        
        subscriptionManager.subscribe(SystemAction.appWillEnterForeground.self) { [weak self] _ in
            // Restore resolution when app returns to foreground
            guard let self = self else { return }
            
            // Apply the strategy-based resolution again
            self.updateResolutionBasedOnStrategy()
            
            print("🔍 ResolutionManager: Restored resolution to \(self.resolutionScaleFactor) for foreground mode")
        }
        
        subscriptionManager.subscribe(SettingsAction.self) { [weak self] action in
            // Listen for settings changes that might affect resolution
            if let action = action as? SettingsAction.updatePerformanceMode {
                self?.handlePerformanceModeChange(action.mode)
            }
        }
    }
    
    /// Handle performance mode changes from settings
    private func handlePerformanceModeChange(_ mode: String) {
        // Map performance mode to resolution strategy
        switch mode {
        case "high":
            resolutionStrategy = .performance
        case "balanced":
            resolutionStrategy = .adaptive
        case "low":
            resolutionStrategy = .memoryConservative
        default:
            resolutionStrategy = .adaptive
        }
    }
    
    // MARK: - Utility Properties and Methods
    
    /// Scaled page size based on the current resolution factor
    var scaledPageSize: CGSize {
        return CGSize(
            width: standardPageSize.width * resolutionScaleFactor,
            height: standardPageSize.height * resolutionScaleFactor
        )
    }
    
    /// Scale a size based on the current resolution factor
    func scale(_ size: CGSize) -> CGSize {
        return CGSize(
            width: size.width * resolutionScaleFactor,
            height: size.height * resolutionScaleFactor
        )
    }
    
    /// Scale a point based on the current resolution factor
    func scale(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * resolutionScaleFactor,
            y: point.y * resolutionScaleFactor
        )
    }
    
    /// Helper to describe the current strategy for logging
    private func describeStrategy(_ strategy: ResolutionStrategy) -> String {
        switch strategy {
        case .fixed(let factor):
            return "fixed(\(factor))"
        case .adaptive:
            return "adaptive"
        case .performance:
            return "performance"
        case .memoryConservative:
            return "memoryConservative"
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    /// Notification posted when the resolution factor changes
    static let resolutionFactorDidChange = Notification.Name("resolutionFactorDidChange")
} 