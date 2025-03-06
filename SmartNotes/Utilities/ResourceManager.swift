//
//  ResourceManager.swift
//  SmartNotes
//
//  Created on 6/15/25.
//
//  This file implements a centralized resource management system for the app.
//  Key responsibilities:
//    - Centralizing multiple caching mechanisms across the app
//    - Prioritizing cached resources based on importance
//    - Providing memory pressure monitoring and adaptive cleanup
//    - Estimating memory usage of cached resources
//    - Preloading resources that are likely to be needed
//    - Providing a unified API for all resource caching
//

import Foundation
import UIKit
import SwiftUI
import PencilKit

// MARK: - Priority Levels

/// Priority levels for cached resources
enum ResourcePriority: Int, Comparable {
    /// Low priority resources are first to be removed under memory pressure
    case low = 0
    
    /// Normal priority for most cached resources
    case normal = 1
    
    /// High priority resources that should be kept in memory longer
    case high = 2
    
    /// Critical resources that should only be removed under severe memory pressure
    case critical = 3
    
    /// Implementation of Comparable protocol
    static func < (lhs: ResourcePriority, rhs: ResourcePriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Resource Types

/// Types of resources that can be cached
enum ResourceType: String {
    /// Note thumbnails from ThumbnailGenerator
    case noteThumbnail
    
    /// Page thumbnails from PageThumbnailGenerator
    case pageThumbnail
    
    /// Templates from TemplateRenderer
    case template
    
    /// Custom resources not fitting into other categories
    case custom
}

// MARK: - Size Estimation Protocol

/// Protocol for objects that can estimate their memory usage
protocol MemorySizeEstimable {
    /// Get estimated memory size in bytes
    func estimatedMemorySize() -> Int
}

// MARK: - Resource Entry

/// A wrapper for cached resources with metadata
struct ResourceEntry<T> {
    /// The cached resource
    let resource: T
    
    /// When the resource was last accessed
    var lastAccessed: Date
    
    /// The priority of this resource
    let priority: ResourcePriority
    
    /// The size of this resource in bytes (if known)
    let size: Int
    
    /// Initialize a new resource entry
    /// - Parameters:
    ///   - resource: The resource to cache
    ///   - priority: Priority level (default: .normal)
    ///   - size: Size in bytes, or nil to estimate
    init(resource: T, priority: ResourcePriority = .normal, size: Int? = nil) {
        self.resource = resource
        self.lastAccessed = Date()
        self.priority = priority
        
        // Determine size from parameter or estimate
        if let explicitSize = size {
            self.size = explicitSize
        } else if let estimable = resource as? MemorySizeEstimable {
            self.size = estimable.estimatedMemorySize()
        } else if let image = resource as? UIImage {
            // Estimate UIImage size
            let bytesPerPixel = 4
            let imageSize = image.size
            let bytesCount = Int(imageSize.width * imageSize.height) * bytesPerPixel
            self.size = bytesCount
        } else {
            // Default estimate for unknown types
            self.size = 1024
        }
    }
    
    /// Update the last accessed time
    mutating func updateAccessTime() {
        self.lastAccessed = Date()
    }
}

// MARK: - Resource Cache

/// A strongly-typed cache for a specific resource type
class ResourceCache<T> {
    /// The type of resources stored in this cache
    let resourceType: ResourceType
    
    /// The resources stored in this cache
    private var resources: [String: ResourceEntry<T>] = [:]
    
    /// The maximum number of resources to store
    private var countLimit: Int
    
    /// The maximum size in bytes for this cache
    private var sizeLimit: Int
    
    /// The total size of all cached resources in bytes
    private(set) var totalSize: Int = 0
    
    /// A queue for thread-safe access
    private let queue = DispatchQueue(label: "com.smartnotes.resourcecache.\(T.self)", attributes: .concurrent)
    
    /// Initialize a new resource cache
    /// - Parameters:
    ///   - resourceType: The type of resources stored
    ///   - countLimit: Maximum number of resources (default: 100)
    ///   - sizeLimit: Maximum size in bytes (default: 50MB)
    init(resourceType: ResourceType, countLimit: Int = 100, sizeLimit: Int = 50 * 1024 * 1024) {
        self.resourceType = resourceType
        self.countLimit = countLimit
        self.sizeLimit = sizeLimit
    }
    
    /// Store a resource in the cache
    /// - Parameters:
    ///   - resource: The resource to store
    ///   - key: The key to store it under
    ///   - priority: The priority level
    ///   - size: Optional explicit size in bytes
    func store(resource: T, forKey key: String, priority: ResourcePriority = .normal, size: Int? = nil) {
        queue.async(flags: .barrier) {
            // Create a new entry
            let entry = ResourceEntry(resource: resource, priority: priority, size: size)
            
            // If we're replacing an existing resource, subtract its size first
            if let existingEntry = self.resources[key] {
                self.totalSize -= existingEntry.size
            }
            
            // Add the new resource and update total size
            self.resources[key] = entry
            self.totalSize += entry.size
            
            // Enforce limits
            self.enforceLimits()
        }
    }
    
    /// Retrieve a resource from the cache
    /// - Parameter key: The key to retrieve
    /// - Returns: The cached resource, or nil if not found
    func retrieve(forKey key: String) -> T? {
        var result: T?
        
        // Synchronously access the resource to avoid race conditions
        queue.sync {
            if var entry = resources[key] {
                entry.updateAccessTime()
                resources[key] = entry
                result = entry.resource
            }
        }
        
        return result
    }
    
    /// Remove a resource from the cache
    /// - Parameter key: The key to remove
    func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            if let entry = self.resources[key] {
                self.totalSize -= entry.size
                self.resources.removeValue(forKey: key)
            }
        }
    }
    
    /// Remove all resources from the cache
    func removeAll() {
        queue.async(flags: .barrier) {
            self.resources.removeAll()
            self.totalSize = 0
        }
    }
    
    /// Get current count of cached items
    var count: Int {
        var result = 0
        queue.sync { result = self.resources.count }
        return result
    }
    
    /// Get all keys in the cache
    var allKeys: [String] {
        var result: [String] = []
        queue.sync { result = Array(self.resources.keys) }
        return result
    }
    
    /// Enforce size and count limits by removing resources
    private func enforceLimits() {
        // Check if we need to reduce the cache size
        if resources.count <= countLimit && totalSize <= sizeLimit {
            return
        }
        
        // Get sorted entries by last access time (oldest first)
        let sortedEntries = resources.sorted { (first, second) -> Bool in
            // First sort by priority
            if first.value.priority != second.value.priority {
                return first.value.priority < second.value.priority
            }
            
            // Then by access time
            return first.value.lastAccessed < second.value.lastAccessed
        }
        
        // Remove entries until we're under the limits
        for (key, entry) in sortedEntries {
            // Stop if we're under both limits
            if resources.count <= countLimit && totalSize <= sizeLimit {
                break
            }
            
            // Remove this entry
            resources.removeValue(forKey: key)
            totalSize -= entry.size
        }
    }
    
    /// Remove resources based on priority level
    /// - Parameter maxPriority: Maximum priority level to remove
    /// - Returns: Number of bytes freed
    func removeResources(withMaxPriority maxPriority: ResourcePriority) -> Int {
        var bytesFreed = 0
        
        queue.async(flags: .barrier) {
            // Get all keys to remove
            let keysToRemove = self.resources.filter { $0.value.priority <= maxPriority }.keys
            
            // Remove each resource and count bytes freed
            for key in keysToRemove {
                if let entry = self.resources[key] {
                    bytesFreed += entry.size
                    self.totalSize -= entry.size
                    self.resources.removeValue(forKey: key)
                }
            }
        }
        
        return bytesFreed
    }
}

// MARK: - Memory Pressure Level

/// Levels of memory pressure for adaptive cleanup
enum MemoryPressureLevel: Int, Comparable {
    /// Normal operation, no memory pressure
    case none = 0
    
    /// Mild memory pressure, clean up low-priority resources
    case mild = 1
    
    /// Moderate memory pressure, clean up low and normal priority
    case moderate = 2
    
    /// Severe memory pressure, only keep critical resources
    case severe = 3
    
    /// Implementation of Comparable protocol
    static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Main Resource Manager

/// Central manager for app-wide caching and resource management
class ResourceManager {
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    static let shared = ResourceManager()
    
    // Private initialization to prevent multiple instances
    private init() {
        // Initialize caches
        initializeCaches()
        
        // Start monitoring memory pressure
        startMemoryPressureMonitoring()
        
        print("📦 ResourceManager: Initialized with \(caches.count) cache namespaces")
    }
    
    // MARK: - Properties
    
    /// The namespace caches for different resource types
    private var caches: [ResourceType: Any] = [:]
    
    /// Total memory limit for all caches combined (100MB default)
    private var totalMemoryLimit: Int = 100 * 1024 * 1024
    
    /// Current memory pressure level
    private var memoryPressureLevel: MemoryPressureLevel = .none
    
    /// Queue for memory pressure handling
    private let memoryPressureQueue = DispatchQueue(label: "com.smartnotes.resourcemanager.memorypressure")
    
    // MARK: - Cache Initialization
    
    /// Initialize the standard caches
    private func initializeCaches() {
        // Initialize thumbnail caches
        let noteThumbnailCache = ResourceCache<UIImage>(
            resourceType: .noteThumbnail,
            countLimit: 100,
            sizeLimit: 25 * 1024 * 1024  // 25MB for note thumbnails
        )
        caches[.noteThumbnail] = noteThumbnailCache
        
        // Initialize page thumbnail cache
        let pageThumbnailCache = ResourceCache<UIImage>(
            resourceType: .pageThumbnail,
            countLimit: 200,
            sizeLimit: 25 * 1024 * 1024  // 25MB for page thumbnails
        )
        caches[.pageThumbnail] = pageThumbnailCache
        
        // Initialize template cache
        let templateCache = ResourceCache<UIImage>(
            resourceType: .template,
            countLimit: 20,
            sizeLimit: 20 * 1024 * 1024  // 20MB for templates
        )
        caches[.template] = templateCache
        
        // Initialize custom cache
        let customCache = ResourceCache<Any>(
            resourceType: .custom,
            countLimit: 50,
            sizeLimit: 10 * 1024 * 1024  // 10MB for other resources
        )
        caches[.custom] = customCache
    }
    
    // MARK: - Generic Cache Access
    
    /// Store a resource in a typed cache
    /// - Parameters:
    ///   - resource: The resource to store
    ///   - key: The key to store it under
    ///   - type: The resource type
    ///   - priority: The priority level
    ///   - size: Optional explicit size in bytes
    func storeResource<T>(_ resource: T, forKey key: String, type: ResourceType, priority: ResourcePriority = .normal, size: Int? = nil) {
        guard let cache = caches[type] as? ResourceCache<T> else {
            print("📦 Error: No cache found for resource type \(type.rawValue)")
            return
        }
        
        cache.store(resource: resource, forKey: key, priority: priority, size: size)
        
        // Log for high memory usage resources
        if let size = size, size > 1024 * 1024 {
            print("📦 Stored large resource: \(type.rawValue)/\(key) (\(formatSize(size)))")
        }
    }
    
    /// Retrieve a resource from a typed cache
    /// - Parameters:
    ///   - key: The key to retrieve
    ///   - type: The resource type
    /// - Returns: The cached resource, or nil if not found
    func retrieveResource<T>(forKey key: String, type: ResourceType) -> T? {
        guard let cache = caches[type] as? ResourceCache<T> else {
            print("📦 Error: No cache found for resource type \(type.rawValue)")
            return nil
        }
        
        return cache.retrieve(forKey: key)
    }
    
    /// Remove a resource from a typed cache
    /// - Parameters:
    ///   - key: The key to remove
    ///   - type: The resource type
    func removeResource(forKey key: String, type: ResourceType) {
        guard let cache = caches[type] as? Any else {
            print("📦 Error: No cache found for resource type \(type.rawValue)")
            return
        }
        
        // Type erasure to call the right method
        if let imageCache = cache as? ResourceCache<UIImage> {
            imageCache.remove(forKey: key)
        } else if let anyCache = cache as? ResourceCache<Any> {
            anyCache.remove(forKey: key)
        }
    }
    
    /// Remove all resources from a typed cache
    /// - Parameter type: The resource type
    func removeAllResources(ofType type: ResourceType) {
        guard let cache = caches[type] as? Any else {
            print("📦 Error: No cache found for resource type \(type.rawValue)")
            return
        }
        
        // Type erasure to call the right method
        if let imageCache = cache as? ResourceCache<UIImage> {
            imageCache.removeAll()
        } else if let anyCache = cache as? ResourceCache<Any> {
            anyCache.removeAll()
        }
    }
    
    /// Preload a resource to ensure it's available when needed
    /// - Parameters:
    ///   - resource: The resource to preload
    ///   - key: The key to store it under
    ///   - type: The resource type
    ///   - priority: The priority level (default: high)
    func preloadResource<T>(_ resource: T, forKey key: String, type: ResourceType, priority: ResourcePriority = .high) {
        // Store with high priority by default for preloaded resources
        storeResource(resource, forKey: key, type: type, priority: priority)
        print("📦 Preloaded resource: \(type.rawValue)/\(key)")
    }
    
    // MARK: - Typed Convenience Methods
    
    /// Store a thumbnail image
    /// - Parameters:
    ///   - image: The thumbnail image
    ///   - noteID: The note ID
    ///   - priority: The priority level
    func storeNoteThumbnail(_ image: UIImage, forNote noteID: UUID, priority: ResourcePriority = .normal) {
        storeResource(image, forKey: noteID.uuidString, type: .noteThumbnail, priority: priority)
    }
    
    /// Retrieve a note thumbnail
    /// - Parameter noteID: The note ID
    /// - Returns: The thumbnail image if available
    func retrieveNoteThumbnail(forNote noteID: UUID) -> UIImage? {
        return retrieveResource(forKey: noteID.uuidString, type: .noteThumbnail)
    }
    
    /// Store a page thumbnail
    /// - Parameters:
    ///   - image: The thumbnail image
    ///   - pageID: The page ID
    ///   - priority: The priority level
    func storePageThumbnail(_ image: UIImage, forPage pageID: UUID, priority: ResourcePriority = .normal) {
        storeResource(image, forKey: pageID.uuidString, type: .pageThumbnail, priority: priority)
    }
    
    /// Retrieve a page thumbnail
    /// - Parameter pageID: The page ID
    /// - Returns: The thumbnail image if available
    func retrievePageThumbnail(forPage pageID: UUID) -> UIImage? {
        return retrieveResource(forKey: pageID.uuidString, type: .pageThumbnail)
    }
    
    /// Store a template image
    /// - Parameters:
    ///   - image: The template image
    ///   - key: The template key
    ///   - priority: The priority level
    func storeTemplate(_ image: UIImage, forKey key: String, priority: ResourcePriority = .normal) {
        storeResource(image, forKey: key, type: .template, priority: priority)
    }
    
    /// Retrieve a template image
    /// - Parameter key: The template key
    /// - Returns: The template image if available
    func retrieveTemplate(forKey key: String) -> UIImage? {
        return retrieveResource(forKey: key, type: .template)
    }
    
    // MARK: - Memory Pressure Handling
    
    /// Start monitoring for memory pressure
    private func startMemoryPressureMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Set up a timer to periodically check memory usage
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    /// Handle memory warning notification from the system
    @objc private func handleMemoryWarning() {
        memoryPressureQueue.async {
            print("⚠️ ResourceManager: Received memory warning, cleaning up resources")
            
            // Go straight to moderate pressure level on system warning
            self.memoryPressureLevel = .moderate
            self.cleanupResources(forPressureLevel: .moderate)
            
            // Gradually recover
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.memoryPressureLevel = .mild
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.memoryPressureLevel = .none
            }
        }
    }
    
    /// Proactively check memory usage and take action if needed
    private func checkMemoryUsage() {
        // Get current app memory usage
        let currentUsage = getMemoryUsage()
        
        // Convert to MB for readable logging and comparisons
        let usageMB = Double(currentUsage) / (1024 * 1024)
        
        memoryPressureQueue.async {
            // Determine pressure level based on memory usage
            let newPressureLevel: MemoryPressureLevel
            
            if usageMB > 800 {
                // Severe: > 800MB
                newPressureLevel = .severe
            } else if usageMB > 500 {
                // Moderate: > 500MB
                newPressureLevel = .moderate
            } else if usageMB > 300 {
                // Mild: > 300MB
                newPressureLevel = .mild
            } else {
                // None: < 300MB
                newPressureLevel = .none
            }
            
            // Only take action if pressure level increased
            if newPressureLevel > self.memoryPressureLevel {
                print("📦 ResourceManager: Memory pressure increased to \(newPressureLevel), current usage: \(Int(usageMB))MB")
                self.memoryPressureLevel = newPressureLevel
                self.cleanupResources(forPressureLevel: newPressureLevel)
            } else if newPressureLevel < self.memoryPressureLevel {
                // Pressure decreased, update level but don't take action
                print("📦 ResourceManager: Memory pressure decreased to \(newPressureLevel), current usage: \(Int(usageMB))MB")
                self.memoryPressureLevel = newPressureLevel
            }
        }
    }
    
    /// Clean up resources based on memory pressure level
    /// - Parameter level: The memory pressure level
    private func cleanupResources(forPressureLevel level: MemoryPressureLevel) {
        var totalBytesFreed = 0
        
        // Define which priority levels to clean up based on pressure
        let maxPriorityToRemove: ResourcePriority
        switch level {
        case .none:
            return  // No cleanup needed
        case .mild:
            maxPriorityToRemove = .low
        case .moderate:
            maxPriorityToRemove = .normal
        case .severe:
            maxPriorityToRemove = .high
        }
        
        // Clean up each cache type
        for (type, cache) in caches {
            var bytesFreed = 0
            
            // Type erasure to call the right method
            if let imageCache = cache as? ResourceCache<UIImage> {
                bytesFreed = imageCache.removeResources(withMaxPriority: maxPriorityToRemove)
            } else if let anyCache = cache as? ResourceCache<Any> {
                bytesFreed = anyCache.removeResources(withMaxPriority: maxPriorityToRemove)
            }
            
            totalBytesFreed += bytesFreed
            
            if bytesFreed > 0 {
                print("📦 ResourceManager: Freed \(formatSize(bytesFreed)) from \(type.rawValue) cache")
            }
        }
        
        // Log total cleanup
        if totalBytesFreed > 0 {
            print("📦 ResourceManager: Total memory freed: \(formatSize(totalBytesFreed))")
        }
    }
    
    /// Get app's memory usage in bytes
    private func getMemoryUsage() -> UInt64 {
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
    
    // MARK: - Memory Stats
    
    /// Get the total memory usage of all caches
    /// - Returns: Total memory usage in bytes
    func getTotalCachedMemory() -> Int {
        var total = 0
        
        for (_, cache) in caches {
            if let imageCache = cache as? ResourceCache<UIImage> {
                total += imageCache.totalSize
            } else if let anyCache = cache as? ResourceCache<Any> {
                total += anyCache.totalSize
            }
        }
        
        return total
    }
    
    /// Get detailed memory stats for all caches
    /// - Returns: Dictionary with resource type and byte counts
    func getDetailedMemoryStats() -> [ResourceType: Int] {
        var stats: [ResourceType: Int] = [:]
        
        for (type, cache) in caches {
            if let imageCache = cache as? ResourceCache<UIImage> {
                stats[type] = imageCache.totalSize
            } else if let anyCache = cache as? ResourceCache<Any> {
                stats[type] = anyCache.totalSize
            }
        }
        
        return stats
    }
    
    /// Format a byte count into a human-readable size string
    /// - Parameter bytes: The number of bytes
    /// - Returns: A human-readable string (e.g., "4.2 MB")
    func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - UIImage Extension

extension UIImage: MemorySizeEstimable {
    /// Estimate the memory size of this image in bytes
    func estimatedMemorySize() -> Int {
        // Calculate based on dimensions and bit depth
        let bytesPerPixel = 4  // Assuming RGBA, 8 bits per channel
        let pixelCount = Int(size.width * size.height)
        
        // Account for scale factor
        let scaledPixelCount = pixelCount * Int(scale * scale)
        
        // Calculate total bytes
        return scaledPixelCount * bytesPerPixel
    }
} 