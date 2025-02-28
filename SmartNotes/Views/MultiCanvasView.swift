//
//  MultiPageCanvasView.swift
//  SmartNotes
//
//  Created by You on 3/5/25.
//

import SwiftUI

struct MultiPageCanvasView: View {
    @Binding var pages: [Page]
    
    // Optional note-wide template:
    @State private var noteTemplate: CanvasTemplate = .none
    
    var body: some View {
        ScrollView {
            // A vertical stack of discrete pages
            VStack(spacing: 40) {
                ForEach(pages.indices, id: \.self) { index in
                    // SinglePageCanvasView is a pinch/zoomable PKCanvas
                    SinglePageCanvasView(
                        page: $pages[index],
                        noteTemplate: $noteTemplate,
                        pageIndex: index,
                        totalPages: pages.count,
                        onNeedNextPage: {
                            // Called when user draws near bottom
                            addNextPageIfNeeded(currentIndex: index)
                        }
                    )
                    .frame(height: 1000) // or 1100, etc.
                    // A typical "page" size might be 792 for letter height,
                    // plus some margin. You can tweak it.

                    // Optional: page indicators
                    Text("Page \(index + 1) of \(pages.count)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 40)
        }
        .background(Color(UIColor.systemGray6)) // or your preferred BG
        .navigationBarItems(
            trailing: HStack {
                // Example "Add Page" button if you want it
                Button(action: addNewPageManually) {
                    Image(systemName: "plus")
                }
                // Example settings
                Button("Settings") {
                    // show a template sheet or etc.
                }
            }
        )
    }
    
    /// If the user drew near the bottom of page `currentIndex`,
    /// ensure there's a next page at `currentIndex + 1`.
    private func addNextPageIfNeeded(currentIndex: Int) {
        // If this is the last page (index == pages.count - 1),
        // automatically append a new page.
        if currentIndex == pages.count - 1 {
            let newPage = Page(drawingData: Data(), template: nil, pageNumber: pages.count + 1)
            pages.append(newPage)
            print("📄 Auto-added page #\(pages.count)")
        }
    }
    
    private func addNewPageManually() {
        let newPage = Page(drawingData: Data(), template: nil, pageNumber: pages.count + 1)
        pages.append(newPage)
        print("📄 Manually added page #\(pages.count)")
    }
}
