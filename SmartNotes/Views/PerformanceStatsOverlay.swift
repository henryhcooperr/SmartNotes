//
//  PerformanceStatsOverlay.swift
//  SmartNotes
//
//  This file provides a real-time performance overlay for monitoring
//  frame rates, memory usage, and other performance metrics.
//

import SwiftUI

struct PerformanceStatsOverlay: View {
    @EnvironmentObject var appSettings: AppSettingsModel
    
    // Stats that get refreshed periodically
    @State private var fps: Double = 0
    @State private var memory: Double = 0
    @State private var resolutionFactor: CGFloat = 0
    
    // Update timer
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PERFORMANCE MONITOR")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            
            Text("FPS: \(String(format: "%.1f", fps))")
                .font(.system(size: 10))
                .foregroundColor(fps < 30 ? .red : .green)
            
            Text("Memory: \(String(format: "%.1f", memory)) MB")
                .font(.system(size: 10))
                .foregroundColor(memory > 500 ? .red : .green)
            
            Text("Resolution: \(String(format: "%.1f", resolutionFactor))x")
                .font(.system(size: 10))
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .padding(.top, 40)
        .padding(.leading, 8)
        .onReceive(timer) { _ in
            updateStats()
        }
        .onAppear {
            updateStats()
        }
    }
    
    private func updateStats() {
        // These would ideally come from your performance monitor
        // For now, we'll use some example/simulated values
        fps = getSimulatedFPS()
        memory = getMemoryUsage()
        resolutionFactor = GlobalSettings.resolutionScaleFactor
    }
    
    // Get a simulated FPS value (for demonstration)
    private func getSimulatedFPS() -> Double {
        return Double.random(in: 55...60)
    }
    
    // Get actual memory usage
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