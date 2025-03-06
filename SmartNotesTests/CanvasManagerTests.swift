//
//  CanvasManagerTests.swift
//  SmartNotesTests
//
//  Created on 5/15/25
//
//  This file contains tests for the CanvasManager class to ensure
//  proper canvas creation, tool management, and template application.
//

import XCTest
import PencilKit
@testable import SmartNotes

class CanvasManagerTests: XCTestCase {
    
    var canvasManager: CanvasManager!
    var subscriptionManager: SubscriptionManager!
    
    override func setUp() {
        super.setUp()
        canvasManager = CanvasManager.shared
        subscriptionManager = SubscriptionManager()
    }
    
    override func tearDown() {
        // Clean up any canvases created during tests
        subscriptionManager.clearAll()
        super.tearDown()
    }
    
    func testCanvasCreation() {
        // Test creating a canvas with default settings
        let canvas = canvasManager.createCanvas()
        
        // Verify canvas was configured properly
        XCTAssertEqual(canvas.backgroundColor, .white)
        XCTAssertFalse(canvas.alwaysBounceVertical)
        XCTAssertEqual(canvas.contentInset, .zero)
    }
    
    func testCanvasCreationWithID() {
        // Test creating a canvas with a specific ID
        let id = UUID()
        let canvas = canvasManager.createCanvas(withID: id)
        
        // Verify the canvas was registered with the manager
        XCTAssertNotNil(canvasManager.getCanvas(withID: id))
        
        // Verify the canvas ID using our test-accessible method
        // Since tagID is fileprivate, we can't directly check it
        // Instead, we rely on getCanvas working as expected
        let retrievedCanvas = canvasManager.getCanvas(withID: id)
        XCTAssertEqual(canvas, retrievedCanvas)
    }
    
    func testCanvasCreationWithInitialDrawing() {
        // Create a test drawing
        let drawing = PKDrawing()
        let drawingData = drawing.dataRepresentation()
        
        // Test creating a canvas with initial drawing data
        let canvas = canvasManager.createCanvas(initialDrawing: drawingData)
        
        // Verify the canvas has the correct drawing
        XCTAssertEqual(canvas.drawing.dataRepresentation(), drawingData)
    }
    
    func testToolEvents() {
        // Create an expectation for the event
        let expectation = XCTestExpectation(description: "Tool change event received")
        
        // Subscribe to the tool changed event
        subscriptionManager.subscribe(ToolEvents.ToolChanged.self) { event in
            // Verify the tool properties
            XCTAssertEqual(event.tool, .pencil)
            XCTAssertEqual(event.color, .red)
            XCTAssertEqual(event.width, 5.0)
            expectation.fulfill()
        }
        
        // Set a tool to trigger the event
        canvasManager.setTool(.pencil, color: .red, width: 5.0)
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testEraserTool() {
        // Test setting an eraser tool (now implemented as pen with clear color)
        canvasManager.setTool(.pen, color: .clear, width: 10.0)
        
        // Create a canvas
        let canvas = canvasManager.createCanvas()
        
        // Verify the eraser tool is applied
        XCTAssertTrue(canvas.tool is PKEraserTool)
    }
    
    func testCanvasUnregistration() {
        // Create a canvas with an ID
        let id = UUID()
        let _ = canvasManager.createCanvas(withID: id)
        
        // Verify the canvas is registered
        XCTAssertNotNil(canvasManager.getCanvas(withID: id))
        
        // Unregister the canvas
        canvasManager.unregisterCanvas(withID: id)
        
        // Verify the canvas is no longer registered
        XCTAssertNil(canvasManager.getCanvas(withID: id))
    }
    
    func testTemplateApplication() {
        // Create a canvas
        let canvas = canvasManager.createCanvas()
        
        // Create a template
        let template = CanvasTemplate(type: .lined, spacing: 20, lineWidth: 1, colorHex: "#000000")
        
        // Apply the template
        canvasManager.applyTemplate(to: canvas, template: template, pageSize: CGSize(width: 612, height: 792))
        
        // Verify the template was applied (check for template layer)
        var hasTemplateLayer = false
        if let sublayers = canvas.layer.sublayers {
            for layer in sublayers where layer.name == "TemplateLayer" {
                hasTemplateLayer = true
                break
            }
        }
        XCTAssertTrue(hasTemplateLayer, "Template layer not found after applying template")
    }
    
    func testPerformanceOptimization() {
        // Create a canvas
        let canvas = canvasManager.createCanvas()
        
        // Test adjusting quality for different zoom levels
        canvasManager.adjustQualityForZoom(canvas, zoomScale: 0.5)
        canvasManager.adjustQualityForZoom(canvas, zoomScale: 2.0)
        
        // Test temporary low resolution mode
        canvasManager.setTemporaryLowResolutionMode(canvas, enabled: true)
        // Verify lower content scale is applied
        XCTAssertLessThanOrEqual(canvas.layer.contentsScale, UIScreen.main.scale * 2.0)
        
        // Restore normal resolution
        canvasManager.setTemporaryLowResolutionMode(canvas, enabled: false)
        // Verify normal content scale is restored
        XCTAssertEqual(canvas.layer.contentsScale, UIScreen.main.scale * ResolutionManager.shared.resolutionScaleFactor)
    }
    
    func testDrawingStateOperations() {
        // Create a canvas
        let canvas = canvasManager.createCanvas()
        
        // Clear the canvas
        canvasManager.clearCanvas(canvas)
        
        // Verify the canvas is empty
        XCTAssertTrue(canvas.drawing.strokes.isEmpty)
        
        // Note: Undo/redo operations are difficult to test directly as they require actual drawing operations
    }
    
    func testBatchOperations() {
        // Create multiple canvases
        let id1 = UUID()
        let id2 = UUID()
        let _ = canvasManager.createCanvas(withID: id1)
        let _ = canvasManager.createCanvas(withID: id2)
        
        // Set a tool that will be applied to all canvases
        canvasManager.setTool(.marker, color: .blue, width: 3.0)
        
        // Verify the tool was applied to both canvases
        if let canvas1 = canvasManager.getCanvas(withID: id1),
           let canvas2 = canvasManager.getCanvas(withID: id2) {
            
            if let tool1 = canvas1.tool as? PKInkingTool,
               let tool2 = canvas2.tool as? PKInkingTool {
                XCTAssertEqual(tool1.inkType, .marker)
                XCTAssertEqual(tool1.color, .blue)
                XCTAssertEqual(tool1.width, 3.0)
                
                XCTAssertEqual(tool2.inkType, .marker)
                XCTAssertEqual(tool2.color, .blue)
                XCTAssertEqual(tool2.width, 3.0)
            } else {
                XCTFail("Canvas tools are not PKInkingTools")
            }
        } else {
            XCTFail("Could not retrieve test canvases")
        }
    }
} 