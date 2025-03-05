import XCTest
import SwiftUI
@testable import SmartNotes

final class CustomNavigationBarTests: XCTestCase {
    
    func testNavBarInitialization() throws {
        // Given
        let title = "Test Title"
        let backCalled = expectation(description: "Back button callback was called")
        backCalled.isInverted = true
        let sidebarCalled = expectation(description: "Sidebar toggle callback was called")
        sidebarCalled.isInverted = true
        let templateCalled = expectation(description: "Template settings callback was called")
        templateCalled.isInverted = true
        let exportCalled = expectation(description: "Export callback was called")
        exportCalled.isInverted = true
        let titleChangedCalled = expectation(description: "Title changed callback was called")
        titleChangedCalled.isInverted = true
        
        // When
        let sut = CustomNavigationBar(
            title: .constant(title),
            onBack: { backCalled.fulfill() },
            onToggleSidebar: { sidebarCalled.fulfill() },
            onShowTemplateSettings: { templateCalled.fulfill() },
            onShowExport: { exportCalled.fulfill() },
            onTitleChanged: { newTitle in
                XCTAssertEqual(newTitle, "New Title")
                titleChangedCalled.fulfill()
            }
        )
        
        // Then
        XCTAssertNotNil(sut)
        // We'll wait briefly to make sure none of the callbacks are triggered unexpectedly
        wait(for: [backCalled, sidebarCalled, templateCalled, exportCalled, titleChangedCalled], timeout: 0.1)
    }
    
    func testBackButtonAction() throws {
        // Given
        let backCalled = expectation(description: "Back button callback was called")
        
        let sut = CustomNavigationBar(
            title: .constant("Test Title"),
            onBack: { backCalled.fulfill() },
            onToggleSidebar: { },
            onShowTemplateSettings: { },
            onShowExport: { }
        )
        
        // When - Call the action directly
        sut.onBack()
        
        // Then
        wait(for: [backCalled], timeout: 1.0)
    }
    
    func testToggleSidebarAction() throws {
        // Given
        let sidebarCalled = expectation(description: "Sidebar toggle callback was called")
        
        let sut = CustomNavigationBar(
            title: .constant("Test Title"),
            onBack: { },
            onToggleSidebar: { sidebarCalled.fulfill() },
            onShowTemplateSettings: { },
            onShowExport: { }
        )
        
        // When
        sut.onToggleSidebar()
        
        // Then
        wait(for: [sidebarCalled], timeout: 1.0)
    }
    
    func testTemplateSettingsAction() throws {
        // Given
        let templateCalled = expectation(description: "Template settings callback was called")
        
        let sut = CustomNavigationBar(
            title: .constant("Test Title"),
            onBack: { },
            onToggleSidebar: { },
            onShowTemplateSettings: { templateCalled.fulfill() },
            onShowExport: { }
        )
        
        // When
        sut.onShowTemplateSettings()
        
        // Then
        wait(for: [templateCalled], timeout: 1.0)
    }
    
    func testExportAction() throws {
        // Given
        let exportCalled = expectation(description: "Export callback was called")
        
        let sut = CustomNavigationBar(
            title: .constant("Test Title"),
            onBack: { },
            onToggleSidebar: { },
            onShowTemplateSettings: { },
            onShowExport: { exportCalled.fulfill() }
        )
        
        // When
        sut.onShowExport()
        
        // Then
        wait(for: [exportCalled], timeout: 1.0)
    }
    
    func testTitleChangeCallback() throws {
        // Given
        let titleChangedExpectation = expectation(description: "Title changed callback was called")
        let expectedNewTitle = "Updated Title"
        
        let title = Binding<String>(
            get: { "Initial Title" },
            set: { _ in }
        )
        
        var receivedTitle: String?
        
        let sut = CustomNavigationBar(
            title: title,
            onBack: { },
            onToggleSidebar: { },
            onShowTemplateSettings: { },
            onShowExport: { },
            onTitleChanged: { newTitle in
                receivedTitle = newTitle
                titleChangedExpectation.fulfill()
            }
        )
        
        // When 
        // Trigger the title change callback manually
        sut.onTitleChanged?(expectedNewTitle)
        
        // Then
        wait(for: [titleChangedExpectation], timeout: 1.0)
        XCTAssertEqual(receivedTitle, expectedNewTitle)
    }
} 