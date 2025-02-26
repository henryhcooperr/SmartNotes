//
//  PDFExporter.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI
import PencilKit
import PDFKit
import UIKit

struct PDFExporter {
    static func exportNoteToPDF(note: Note, pageRects: [CGRect]) -> URL? {
        // Create PDF context
        let pdfMetadata = [
            kCGPDFContextCreator: "SmartNotes",
            kCGPDFContextAuthor: "User",
            kCGPDFContextTitle: note.title
        ]
        
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("\(note.title.isEmpty ? "Untitled" : note.title).pdf")
        
        // Create PDF context with standardized US Letter page size
        guard let pdfContext = CGContext(pdfURL as CFURL, mediaBox: nil, pdfMetadata as CFDictionary) else {
            print("Could not create PDF context")
            return nil
        }
        
        // Create drawing from note data
        let drawing = PKDrawing.fromData(note.drawingData)
        
        // For each page (rect), create a PDF page and render the content
        for (index, pageRect) in pageRects.enumerated() {
            // Begin PDF page
            pdfContext.beginPDFPage(nil)
            
            // Add title to first page only
            if index == 0 && !note.title.isEmpty {
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: UIColor.black
                ]
                
                let titleString = NSAttributedString(string: note.title, attributes: titleAttributes)
                let titleRect = CGRect(x: 50, y: 50, width: pageRect.width - 100, height: 50)
                
                // Draw title
                UIGraphicsPushContext(pdfContext)
                titleString.draw(in: titleRect)
                UIGraphicsPopContext()
            }
            
            // Create bounds for this page's portion of the drawing
            let bounds = CGRect(
                x: pageRect.origin.x,
                y: pageRect.origin.y,
                width: pageRect.width,
                height: pageRect.height
            )
            
            // Create a copy of the drawing with only the strokes in this page's bounds
            let pageImage = drawing.image(from: bounds, scale: 2.0)
            
            // Draw the image
            UIGraphicsPushContext(pdfContext)
            // Draw at the origin of the page with appropriate padding
            let yOffset: CGFloat = index == 0 && !note.title.isEmpty ? 100 : 50 // Extra space for title on first page
            pageImage.draw(in: CGRect(x: 50, y: yOffset, width: pageRect.width - 100, height: pageRect.height - 100))
            UIGraphicsPopContext()
            
            // End the PDF page
            pdfContext.endPDFPage()
        }
        
        // End the PDF document
        pdfContext.closePDF()
        
        return pdfURL
    }
    
    static func presentPDFForSharing(url: URL, from viewController: UIViewController) {
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Present the activity view controller
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        viewController.present(activityViewController, animated: true, completion: nil)
    }
}

// SwiftUI View extension to get the UIViewController
extension View {
    func getPresentingViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        var currentController = rootViewController
        while let presentedController = currentController.presentedViewController {
            currentController = presentedController
        }
        
        return currentController
    }
}
