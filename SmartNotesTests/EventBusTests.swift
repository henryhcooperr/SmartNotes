//
//  EventBusTests.swift
//  SmartNotesTests
//
//  Created on 5/15/25
//

import XCTest
@testable import SmartNotes

class EventBusTests: XCTestCase {
    
    var subscriptionManager: SubscriptionManager!
    
    override func setUp() {
        super.setUp()
        subscriptionManager = SubscriptionManager()
    }
    
    override func tearDown() {
        subscriptionManager.clearAll()
        super.tearDown()
    }
    
    func testEventSubscriptionAndPosting() {
        // Create an expectation for the event
        let expectation = XCTestExpectation(description: "Event received")
        
        // Subscribe to an event
        subscriptionManager.subscribe(ToolEvents.ToolChanged.self) { event in
            XCTAssertEqual(event.tool, .pen)
            XCTAssertEqual(event.color, .blue)
            XCTAssertEqual(event.width, 3.0)
            expectation.fulfill()
        }
        
        // Post an event
        let event = ToolEvents.ToolChanged(tool: .pen, color: .blue, width: 3.0)
        EventBus.shared.publish(event)
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUnsubscribe() {
        // Create an expectation that should NOT be fulfilled
        let expectation = XCTestExpectation(description: "Event should not be received")
        expectation.isInverted = true  // We expect this NOT to be fulfilled
        
        // Subscribe to an event
        let token = subscriptionManager.subscribe(ToolEvents.ToolChanged.self) { _ in
            expectation.fulfill()
        }
        
        // Clear subscriptions
        subscriptionManager.clearAll()
        
        // Post an event - should not trigger the callback
        let event = ToolEvents.ToolChanged(tool: .pen, color: .blue, width: 3.0)
        EventBus.shared.publish(event)
        
        // Wait a short time to make sure the event isn't received
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testMultipleSubscribers() {
        // Create expectations for both subscribers
        let expectation1 = XCTestExpectation(description: "Event received by subscriber 1")
        let expectation2 = XCTestExpectation(description: "Event received by subscriber 2")
        
        // Create a second subscriber object with its own subscription manager
        let subscriber2 = AnotherTestSubscriber()
        let subscriberManager2 = SubscriptionManager()
        
        // Subscribe to events
        subscriptionManager.subscribe(ToolEvents.ToolChanged.self) { _ in
            expectation1.fulfill()
        }
        
        subscriberManager2.subscribe(ToolEvents.ToolChanged.self) { _ in
            expectation2.fulfill()
        }
        
        // Post an event
        let event = ToolEvents.ToolChanged(tool: .pen, color: .blue, width: 3.0)
        EventBus.shared.publish(event)
        
        // Wait for both expectations
        wait(for: [expectation1, expectation2], timeout: 1.0)
        
        // Cleanup
        subscriptionManager.clearAll()
        subscriberManager2.clearAll()
    }
    
    func testWeakSubscriberReferences() {
        // Create a scope where the subscriber will be deallocated
        var expectation: XCTestExpectation? = XCTestExpectation(description: "Event should not be received")
        expectation?.isInverted = true  // We expect this NOT to be fulfilled
        
        do {
            // Create a temporary subscription manager
            let tempManager = SubscriptionManager()
            
            // Subscribe to an event
            tempManager.subscribe(ToolEvents.ToolChanged.self) { _ in
                expectation?.fulfill()
            }
            
            // Temporary manager goes out of scope here and should be deallocated
        }
        
        // Force any remaining cleanup
        DispatchQueue.main.async {
            // Post an event - should not trigger the callback since subscriber was deallocated
            let event = ToolEvents.ToolChanged(tool: .pen, color: .blue, width: 3.0)
            EventBus.shared.publish(event)
            
            // Wait a short time to make sure the event isn't received
            if let exp = expectation {
                self.wait(for: [exp], timeout: 0.5)
            }
            expectation = nil
        }
    }
}

// Helper classes for testing
class AnotherTestSubscriber {}
class TemporarySubscriber {} 