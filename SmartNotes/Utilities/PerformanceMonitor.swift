//
//  PerformanceMonitor.swift
//  SmartNotes
//
//  This file provides performance monitoring tools to help diagnose and optimize
//  the app's rendering and interaction performance.
//

import Foundation
import UIKit

class PerformanceMonitor {
    // Singleton instance
    static let shared = PerformanceMonitor()
    
    // Whether monitoring is enabled
    private var isMonitoringEnabled = false
    
    // Frame time tracking
    private var frameStartTime: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private let maxFrameCount = 60
    
    // Display link for frame monitoring
    private var displayLink: CADisplayLink?
    
    // Memory tracking
    private var memoryUsage: [Double] = []
    private let maxMemorySamples = 30
    private var memoryCheckTimer: Timer?
    
    // Operation timing
    private var operations: [String: CFTimeInterval] = [:]
    
    // Enable or disable monitoring
    func setMonitoringEnabled(_ enabled: Bool) {
        // If the state hasn't changed, don't do anything
        if isMonitoringEnabled == enabled {
            return
        }
        
        isMonitoringEnabled = enabled
        
        if enabled {
            // Start frame monitoring if enabled
            startFrameMonitoring()
            startMemoryMonitoring()
            print("📊 Performance monitoring enabled")
        } else {
            // Stop all monitoring
            stopFrameMonitoring()
            stopMemoryMonitoring()
            operations.removeAll()
            print("📊 Performance monitoring disabled")
        }
    }
    
    // MARK: - Frame Monitoring
    
    private func startFrameMonitoring() {
        stopFrameMonitoring() // Ensure any existing monitoring is stopped
        
        frameTimes.removeAll()
        frameStartTime = 0
        
        // Use CADisplayLink to track frame rates
        displayLink = CADisplayLink(target: self, selector: #selector(frameCallback))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopFrameMonitoring() {
        // Stop tracking frames by invalidating the display link
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func frameCallback(displayLink: CADisplayLink) {
        guard isMonitoringEnabled else { return }
        
        let currentTime = CACurrentMediaTime()
        
        if frameStartTime != 0 {
            let frameDuration = currentTime - frameStartTime
            frameTimes.append(frameDuration)
            
            // Keep only recent frames
            if frameTimes.count > maxFrameCount {
                frameTimes.removeFirst()
            }
            
            // Periodically log performance
            if frameTimes.count % 30 == 0 {
                reportFramePerformance()
            }
        }
        
        frameStartTime = currentTime
    }
    
    private func reportFramePerformance() {
        guard !frameTimes.isEmpty else { return }
        
        // Only log to console if debug mode is enabled
        guard GlobalSettings.debugModeEnabled else { return }
        
        let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        let worstFrameTime = frameTimes.max() ?? 0
        let fps = 1.0 / avgFrameTime
        
        print("📊 Performance: \(String(format: "%.1f", fps)) FPS (avg frame: \(String(format: "%.1f", avgFrameTime * 1000)) ms, worst: \(String(format: "%.1f", worstFrameTime * 1000)) ms)")
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        stopMemoryMonitoring() // Ensure any existing monitoring is stopped
        
        memoryUsage.removeAll()
        
        // Schedule periodic memory checks
        scheduleMemeoryCheck()
    }
    
    private func stopMemoryMonitoring() {
        // Stop scheduled checks
        memoryCheckTimer?.invalidate()
        memoryCheckTimer = nil
    }
    
    private func scheduleMemeoryCheck() {
        guard isMonitoringEnabled else { return }
        
        // Sample memory
        sampleMemoryUsage()
        
        // Schedule next check
        memoryCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.scheduleMemeoryCheck()
        }
    }
    
    private func sampleMemoryUsage() {
        let usedMemoryMB = getMemoryUsage()
        memoryUsage.append(usedMemoryMB)
        
        // Keep only recent samples
        if memoryUsage.count > maxMemorySamples {
            memoryUsage.removeFirst()
        }
        
        // Report if memory jumps significantly
        if memoryUsage.count >= 2 {
            let previous = memoryUsage[memoryUsage.count - 2]
            let current = memoryUsage.last!
            
            if current > previous * 1.2 && current - previous > 50 {
                print("⚠️ Memory usage increased significantly: \(String(format: "%.1f", previous)) MB → \(String(format: "%.1f", current)) MB")
            }
        }
        
        // Log memory usage periodically
        if memoryUsage.count % 6 == 0 {
            reportMemoryUsage()
        }
    }
    
    private func reportMemoryUsage() {
        guard let currentMemory = memoryUsage.last else { return }
        print("📊 Memory usage: \(String(format: "%.1f", currentMemory)) MB")
    }
    
    // MARK: - Operation Timing
    
    func startOperation(_ name: String) {
        guard isMonitoringEnabled else { return }
        
        operations[name] = CACurrentMediaTime()
    }
    
    func endOperation(_ name: String) {
        guard isMonitoringEnabled else { return }
        
        if let startTime = operations[name] {
            let duration = CACurrentMediaTime() - startTime
            print("📊 Operation '\(name)' took \(String(format: "%.1f", duration * 1000)) ms")
            operations.removeValue(forKey: name)
        }
    }
    
    // MARK: - Helpers
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)
        } else {
            return 0
        }
    }
}

// MARK: - Extensions

// Convenience extension for timing code blocks
extension PerformanceMonitor {
    func time(_ name: String, _ block: () -> Void) {
        startOperation(name)
        block()
        endOperation(name)
    }
}

// Example usage:
// PerformanceMonitor.shared.setMonitoringEnabled(true)
// PerformanceMonitor.shared.time("Drawing template") {
//    // Code to measure
// } 