//
//  ResolutionManager.swift
//  SmartNotes
//
//  Created on 5/8/25
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
        observers.removeAll { weakObserver in
            return weakObserver.observer === observer
        }
    }
    
    /// Register an observer (alias for addObserver)
    func registerForResolutionChanges(observer: ResolutionChangeObserver) {
        addObserver(observer)
    }
    
    /// Unregister an observer (alias for removeObserver)
    func unregisterFromResolutionChanges(observer: ResolutionChangeObserver) {
        removeObserver(observer)
    }
    
    /// Remove nil references from the observers array
    private func cleanupObservers() {
        observers.removeAll { weakObserver in
            return weakObserver.observer == nil
        }
    }
    
    /// Notify all observers of a resolution change
    private func notifyObserversOfResolutionChange() {
        // First clean up any nil references
        cleanupObservers()
        
        // Then notify all observers
        for weakObserver in observers {
            weakObserver.observer?.resolutionDidChange(newResolutionFactor: resolutionScaleFactor)
        }
    }
    
    /// Set the resolution scale factor internally
    private func setInternalResolutionFactor(_ newValue: CGFloat) {
        if _resolutionScaleFactor != newValue {
            let oldValue = _resolutionScaleFactor
            _resolutionScaleFactor = newValue
            
            // Notify observers of the change
            notifyObserversOfResolutionChange()
            
            // Post notification for components using NotificationCenter
            NotificationCenter.default.post(
                name: .resolutionFactorDidChange,
                object: nil,
                userInfo: [
                    "oldFactor": oldValue,
                    "newFactor": newValue
                ]
            )
            
            // Log the change
            print("🔍 ResolutionManager: Resolution scale factor changed from \(oldValue) to \(newValue)")
        }
    }
    
    // MARK: - Resolution Management
    
    /// Manually set the resolution scale factor
    func setResolutionScaleFactor(_ factor: CGFloat) {
        // Ensure factor is within reasonable bounds
        let boundedFactor = min(max(factor, 1.0), 4.0)
        
        // Set the new factor
        setInternalResolutionFactor(boundedFactor)
        
        // Switch to fixed strategy since we're manually setting the factor
        _resolutionStrategy = .fixed(factor: boundedFactor)
    }
    
    /// Set resolution scale factor (alias for clarity in calling code)
    func setResolutionFactor(_ factor: CGFloat) {
        setResolutionScaleFactor(factor)
    }
    
    /// Use adaptive resolution strategy
    func useAdaptiveResolution() {
        resolutionStrategy = .adaptive
    }
    
    /// Reset to the default resolution based on device capabilities
    func resetToDefaultResolution() {
        _resolutionStrategy = .adaptive
        updateResolutionBasedOnStrategy()
    }
    
    /// Update resolution based on the current strategy
    private func updateResolutionBasedOnStrategy() {
        // Skip if under memory pressure (will be handled by memory pressure system)
        if isUnderMemoryPressure {
            return
        }
        
        switch _resolutionStrategy {
        case .fixed(let factor):
            setInternalResolutionFactor(factor)
            
        case .adaptive:
            setInternalResolutionFactor(calculateOptimalResolutionFactor())
            
        case .performance:
            // Higher resolution for better quality
            setInternalResolutionFactor(calculateOptimalResolutionFactor() * 1.2)
            
        case .memoryConservative:
            // Lower resolution to conserve memory
            setInternalResolutionFactor(min(calculateOptimalResolutionFactor(), 1.5))
        }
    }
    
    /// Calculate the optimal resolution factor based on device capabilities
    private func calculateOptimalResolutionFactor() -> CGFloat {
        let device = UIDevice.current
        let processorCount = ProcessInfo.processInfo.processorCount
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Memory in GB (approximate)
        let memoryInGB = Double(totalMemory) / 1_000_000_000.0
        
        // Determine factor based on device capabilities
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
    
    /// Get a human-readable description of the current resolution strategy
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
    
    // MARK: - Memory Pressure Handling
    
    /// Start monitoring for memory pressure notifications
    private func startMemoryPressureMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarningNotification),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    /// Handle memory pressure notification from UIApplication
    @objc private func handleMemoryWarningNotification() {
        handleMemoryPressureInternal()
    }
    
    /// Handle memory pressure internally with the core logic
    private func handleMemoryPressureInternal() {
        print("⚠️ Memory warning received - reducing resolution temporarily")
        
        // Already under memory pressure
        if isUnderMemoryPressure {
            return
        }
        
        // Mark that we're under memory pressure
        isUnderMemoryPressure = true
        
        // Store the original resolution for restoration later
        originalResolutionFactor = resolutionScaleFactor
        
        // Reduce resolution temporarily
        setInternalResolutionFactor(min(resolutionScaleFactor, 1.5))
        
        // After a delay, restore the resolution if pressure has eased
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.attemptToRestoreResolution()
        }
    }
    
    /// Handle memory pressure for testing with a specified level
    @objc func handleMemoryPressure(level: Int) {
        print("⚠️ Memory warning received (level: \(level)) - reducing resolution temporarily")
        handleMemoryPressureInternal()
    }
    
    /// Attempt to restore the original resolution after memory pressure eases
    private func attemptToRestoreResolution() {
        print("🔄 Attempting to restore resolution after memory pressure")
        
        // Restore resolution gradually
        if let originalFactor = originalResolutionFactor {
            // Gradually increase back to original, but no more than 0.5 at a time
            let newFactor = min(originalFactor, resolutionScaleFactor + 0.5)
            setInternalResolutionFactor(newFactor)
            
            // If we haven't fully restored yet, try again after a delay
            if newFactor < originalFactor {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.attemptToRestoreResolution()
                }
            } else {
                // We've fully restored, reset memory pressure flag
                isUnderMemoryPressure = false
                originalResolutionFactor = nil
            }
        } else {
            // No original factor stored, just reset the flag
            isUnderMemoryPressure = false
        }
    }
    
    // MARK: - Scaling Utilities
    
    /// The scaled page size after applying the resolution factor
    var scaledPageSize: CGSize {
        return CGSize(
            width: standardPageSize.width * resolutionScaleFactor,
            height: standardPageSize.height * resolutionScaleFactor
        )
    }
    
    /// The minimum zoom scale for scroll views, adjusted for resolution factor
    var minimumZoomScale: CGFloat {
        return 0.25 / resolutionScaleFactor
    }
    
    /// The maximum zoom scale for scroll views, adjusted for resolution factor
    var maximumZoomScale: CGFloat {
        return 3.75 / resolutionScaleFactor
    }
    
    /// The default initial zoom scale, adjusted to maintain the same view size
    var defaultZoomScale: CGFloat {
        return 1.0 / resolutionScaleFactor
    }
    
    /// Apply resolution scaling to a value
    func applyResolutionScaling(to value: CGFloat) -> CGFloat {
        return value * resolutionScaleFactor
    }
    
    /// Remove resolution scaling from a value
    func removeResolutionScaling(from value: CGFloat) -> CGFloat {
        return value / resolutionScaleFactor
    }
    
    /// Apply resolution scaling to a point
    func applyResolutionScaling(to point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * resolutionScaleFactor,
            y: point.y * resolutionScaleFactor
        )
    }
    
    /// Remove resolution scaling from a point
    func removeResolutionScaling(from point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x / resolutionScaleFactor,
            y: point.y / resolutionScaleFactor
        )
    }
    
    /// Apply resolution scaling to a size
    func applyResolutionScaling(to size: CGSize) -> CGSize {
        return CGSize(
            width: size.width * resolutionScaleFactor,
            height: size.height * resolutionScaleFactor
        )
    }
    
    /// Remove resolution scaling from a size
    func removeResolutionScaling(from size: CGSize) -> CGSize {
        return CGSize(
            width: size.width / resolutionScaleFactor,
            height: size.height / resolutionScaleFactor
        )
    }
    
    /// Apply resolution scaling to a rect
    func applyResolutionScaling(to rect: CGRect) -> CGRect {
        return CGRect(
            x: rect.origin.x * resolutionScaleFactor,
            y: rect.origin.y * resolutionScaleFactor,
            width: rect.width * resolutionScaleFactor,
            height: rect.height * resolutionScaleFactor
        )
    }
    
    /// Remove resolution scaling from a rect
    func removeResolutionScaling(from rect: CGRect) -> CGRect {
        return CGRect(
            x: rect.origin.x / resolutionScaleFactor,
            y: rect.origin.y / resolutionScaleFactor,
            width: rect.width / resolutionScaleFactor,
            height: rect.height / resolutionScaleFactor
        )
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Notification sent when the resolution scale factor changes
    static let resolutionFactorDidChange = Notification.Name("ResolutionFactorDidChange")
} 