//
//  Item.swift
//  SmartNotes
//
//  Created by Henry Cooper on 2/25/25.
//
import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
