//
//  ResourceMonitorView.swift
//  SmartNotes
//
//  Created on 6/15/25.
//
//  This file provides a monitoring UI for visualizing resource usage
//  and validating the ResourceManager implementation.
//

import SwiftUI

struct ResourceMonitorView: View {
    @State private var isExpanded = false
    @State private var resourceStats: [ResourceType: Int] = [:]
    @State private var totalMemoryUsage: Int = 0
    @State private var appMemoryUsage: Double = 0
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row with expand button
            HStack {
                Text("RESOURCE MONITOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                        .font(.system(size: 10))
                }
            }
            
            // Always show total usage
            HStack {
                Text("App Memory:")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(appMemoryUsage)) MB")
                    .font(.system(size: 10))
                    .foregroundColor(appMemoryUsage > 500 ? .red : .green)
            }
            
            HStack {
                Text("Cached Resources:")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(formatBytes(totalMemoryUsage))
                    .font(.system(size: 10))
                    .foregroundColor(totalMemoryUsage > 50_000_000 ? .orange : .green)
            }
            
            // Show detailed stats if expanded
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, 2)
                
                ForEach(ResourceType.allCases, id: \.self) { type in
                    HStack {
                        Text("\(type.displayName):")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(formatBytes(resourceStats[type] ?? 0))
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, 2)
                
                // Action buttons
                HStack(spacing: 8) {
                    Button("Clear All") {
                        clearAllCaches()
                    }
                    .buttonStyle(ResourceMonitorButtonStyle())
                    
                    Button("Test Load") {
                        testLoadResources()
                    }
                    .buttonStyle(ResourceMonitorButtonStyle())
                    
                    Button("Force GC") {
                        forceMemoryWarning()
                    }
                    .buttonStyle(ResourceMonitorButtonStyle())
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .frame(width: 200)
        .padding(.top, 40)
        .padding(.trailing, 8)
        .onAppear {
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
    }
    
    // Start periodic updates
    private func startMonitoring() {
        // Update immediately
        updateStats()
        
        // Set up timer for periodic updates
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            updateStats()
        }
    }
    
    // Stop the update timer
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // Update the statistics
    private func updateStats() {
        resourceStats = ResourceManager.shared.getDetailedMemoryStats()
        totalMemoryUsage = ResourceManager.shared.getTotalCachedMemory()
        
        // Get app memory usage
        let memoryUsage = getAppMemoryUsage()
        appMemoryUsage = Double(memoryUsage) / (1024 * 1024) // Convert to MB
    }
    
    // Format bytes to a readable string
    private func formatBytes(_ bytes: Int) -> String {
        return ResourceManager.shared.formatSize(bytes)
    }
    
    // Clear all caches
    private func clearAllCaches() {
        for type in ResourceType.allCases {
            ResourceManager.shared.removeAllResources(ofType: type)
        }
        updateStats()
    }
    
    // Test loading resources
    private func testLoadResources() {
        // Create some test images of different sizes
        for i in 1...10 {
            let size = CGSize(width: 100 * i, height: 100 * i)
            
            UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            
            // Draw some text on the image
            let text = "Test \(i)"
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            
            text.draw(at: CGPoint(x: 10, y: 10), withAttributes: textAttributes)
            
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                
                // Store with different priorities based on index
                let priority: ResourcePriority = i < 3 ? .critical : 
                                               i < 5 ? .high :
                                               i < 8 ? .normal : .low
                
                // Distribute across different cache types
                if i % 3 == 0 {
                    ResourceManager.shared.storeResource(image, forKey: "test_\(i)", type: .noteThumbnail, priority: priority)
                } else if i % 3 == 1 {
                    ResourceManager.shared.storeResource(image, forKey: "test_\(i)", type: .pageThumbnail, priority: priority)
                } else {
                    ResourceManager.shared.storeResource(image, forKey: "test_\(i)", type: .template, priority: priority)
                }
            } else {
                UIGraphicsEndImageContext()
            }
        }
        
        // Update stats after loading
        updateStats()
    }
    
    // Force a memory warning
    private func forceMemoryWarning() {
        // Simulate a memory warning
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Update after a brief delay to see the effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateStats()
        }
    }
    
    // Get app memory usage
    private func getAppMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

// Custom button style for the monitor
struct ResourceMonitorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue.opacity(0.6))
            .cornerRadius(4)
            .foregroundColor(.white)
    }
}

// Extension to ResourceType for display names
extension ResourceType: CaseIterable {
    static var allCases: [ResourceType] {
        return [.noteThumbnail, .pageThumbnail, .template, .custom]
    }
    
    var displayName: String {
        switch self {
        case .noteThumbnail:
            return "Note Thumbnails"
        case .pageThumbnail:
            return "Page Thumbnails"
        case .template:
            return "Templates"
        case .custom:
            return "Custom Resources"
        }
    }
}

// Preview provider
struct ResourceMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                ResourceMonitorView()
                    .padding()
            }
        }
    }
} 