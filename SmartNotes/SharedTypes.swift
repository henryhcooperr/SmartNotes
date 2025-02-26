//
//  SharedTypes.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI

// A simple identifiable wrapper for note index
struct NoteIdentifier: Identifiable {
    let id = UUID()
    let index: Int
}
