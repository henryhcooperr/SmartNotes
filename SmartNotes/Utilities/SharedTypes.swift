//
//  SharedTypes.swift
//  SmartNotes
//
//  Created on 2/25/25.
//
//  This file contains shared type definitions used across the app.
//  Currently it defines:
//    - NoteIdentifier: A simple wrapper for note index with a UUID
//      that can be used in places requiring Identifiable conformance
//
//  This file can be expanded with additional shared types and
//  utilities as the app grows.
//

import SwiftUI

// A simple identifiable wrapper for note index
struct NoteIdentifier: Identifiable {
    let id = UUID()
    let index: Int
}
