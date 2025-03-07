import Foundation
import Combine

/// Performance metric event published by the performance middleware
struct PerformanceMetric: Event {
    static var description: String = "Performance metric event"
    
    /// The action that was measured
    let action: Action
    
    /// The time it took to process the action in milliseconds
    let processingTimeMs: Double
    
    /// Timestamp of when the action was processed
    let timestamp: Date
    
    /// Creates a new PerformanceMetric event
    init(action: Action, processingTimeMs: Double) {
        self.action = action
        self.processingTimeMs = processingTimeMs
        self.timestamp = Date()
    }
}

/// Middleware that tracks performance metrics for action processing
class PerformanceMiddleware {
    private let eventBus = EventBus.shared
    private var metrics: [PerformanceMetric] = []
    private let maxStoredMetrics = 1000
    private var actionStartTimes: [ObjectIdentifier: CFAbsoluteTime] = [:]
    
    /// Threshold for slow actions in milliseconds
    private let slowActionThresholdMs: Double = 100
    
    /// Creates a new PerformanceMiddleware
    init() {}
    
    /// The middleware function that will be called before each action is processed
    func beforeMiddleware(state: AppState, action: Action) {
        let actionId = ObjectIdentifier(action as AnyObject)
        actionStartTimes[actionId] = CFAbsoluteTimeGetCurrent()
    }
    
    /// The middleware function that will be called after each action is processed
    func afterMiddleware(state: AppState, action: Action) {
        let actionId = ObjectIdentifier(action as AnyObject)
        
        guard let startTime = actionStartTimes[actionId] else { return }
        
        // Calculate processing time in milliseconds
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTimeMs = (endTime - startTime) * 1000
        
        // Create and store the metric
        let metric = PerformanceMetric(action: action, processingTimeMs: processingTimeMs)
        metrics.append(metric)
        
        // Keep the metrics array limited
        if metrics.count > maxStoredMetrics {
            metrics.removeFirst()
        }
        
        // Log slow actions
        if processingTimeMs > slowActionThresholdMs {
            print("⚠️ SLOW ACTION: \(action.description) took \(String(format: "%.2f", processingTimeMs))ms")
        }
        
        // Clean up
        actionStartTimes.removeValue(forKey: actionId)
        
        // Publish performance metric event
        eventBus.publish(metric)
    }
    
    /// Get performance metrics for a specific action type
    /// - Parameter actionType: The type of action to get metrics for
    /// - Returns: The metrics for the specified action type
    func getMetrics(forActionType actionType: String) -> [PerformanceMetric] {
        return metrics.filter { String(describing: type(of: $0.action)) == actionType }
    }
    
    /// Get average processing time for a specific action type
    /// - Parameter actionType: The type of action to get the average for
    /// - Returns: The average processing time in milliseconds, or nil if no metrics are available
    func getAverageProcessingTime(forActionType actionType: String) -> Double? {
        let actionMetrics = getMetrics(forActionType: actionType)
        guard !actionMetrics.isEmpty else { return nil }
        
        let totalTime = actionMetrics.reduce(0.0) { $0 + $1.processingTimeMs }
        return totalTime / Double(actionMetrics.count)
    }
    
    /// Get the slowest actions
    /// - Parameter count: The number of actions to return
    /// - Returns: The slowest actions
    func getSlowestActions(count: Int = 10) -> [PerformanceMetric] {
        let sortedMetrics = metrics.sorted { $0.processingTimeMs > $1.processingTimeMs }
        return Array(sortedMetrics.prefix(count))
    }
    
    /// Clear all metrics
    func clearMetrics() {
        metrics.removeAll()
        actionStartTimes.removeAll()
    }
} 