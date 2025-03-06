import XCTest
@testable import SmartNotes

class ResolutionManagerTests: XCTestCase {
    
    var resolutionManager: ResolutionManager!
    
    override func setUp() {
        super.setUp()
        resolutionManager = ResolutionManager.shared
    }
    
    override func tearDown() {
        // Reset to default after each test
        resolutionManager.useAdaptiveResolution()
        super.tearDown()
    }
    
    func testInitialResolutionValues() {
        // Test initial values match expectations
        XCTAssertGreaterThanOrEqual(resolutionManager.resolutionScaleFactor, 1.0)
        // Test scaled page size is calculated correctly
        XCTAssertEqual(resolutionManager.scaledPageSize.width, 612 * resolutionManager.resolutionScaleFactor)
        XCTAssertEqual(resolutionManager.scaledPageSize.height, 792 * resolutionManager.resolutionScaleFactor)
    }
    
    func testSettingCustomResolutionFactor() {
        // Test setting a custom resolution factor
        let testFactor: CGFloat = 2.5
        resolutionManager.setResolutionFactor(testFactor)
        
        XCTAssertEqual(resolutionManager.resolutionScaleFactor, testFactor)
        XCTAssertEqual(resolutionManager.scaledPageSize.width, 612 * testFactor)
        XCTAssertEqual(resolutionManager.scaledPageSize.height, 792 * testFactor)
    }
    
    func testObserverRegistrationAndNotification() {
        // Create a mock observer
        class MockObserver: ResolutionChangeObserver {
            var resolutionChangedCalled = false
            
            func resolutionDidChange(newResolutionFactor: CGFloat) {
                resolutionChangedCalled = true
            }
        }
        
        let mockObserver = MockObserver()
        
        // Register the observer
        resolutionManager.registerForResolutionChanges(observer: mockObserver)
        
        // Change resolution to trigger notification
        resolutionManager.setResolutionFactor(2.0)
        
        // Verify the observer was notified
        XCTAssertTrue(mockObserver.resolutionChangedCalled)
        
        // Clean up
        resolutionManager.unregisterFromResolutionChanges(observer: mockObserver)
    }
    
    func testMemoryPressureHandling() {
        // Set a higher resolution
        resolutionManager.setResolutionFactor(3.0)
        XCTAssertEqual(resolutionManager.resolutionScaleFactor, 3.0)
        
        // Simulate memory pressure
        resolutionManager.handleMemoryPressure(level: 2)
        
        // Verify resolution was reduced
        XCTAssertLessThan(resolutionManager.resolutionScaleFactor, 3.0)
    }
    
    func testAdaptiveResolution() {
        // Test switching to adaptive resolution
        let customFactor: CGFloat = 2.5
        resolutionManager.setResolutionFactor(customFactor)
        XCTAssertEqual(resolutionManager.resolutionScaleFactor, customFactor)
        
        // Switch to adaptive
        resolutionManager.useAdaptiveResolution()
        
        // Verify it's not using the custom factor anymore
        XCTAssertNotEqual(resolutionManager.resolutionScaleFactor, customFactor)
    }
} 