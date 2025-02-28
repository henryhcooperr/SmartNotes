//
//  Page.swift
//  SmartNotes
//
//  Created by You on 3/1/25.
//

import SwiftUI
import PencilKit

struct Page: Identifiable, Codable, Hashable {
    let id: UUID
    var drawingData: Data
    // If each page can have its own template, store it here:
    var template: CanvasTemplate?
    
    // In case you want to keep track of an explicit page number;
    // you can also rely on array indices in the Note’s `pages`.
    var pageNumber: Int
    
    init(id: UUID = UUID(),
         drawingData: Data = Data(),
         template: CanvasTemplate? = nil,
         pageNumber: Int = 1) {
        self.id = id
        self.drawingData = drawingData
        self.template = template
        self.pageNumber = pageNumber
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}
