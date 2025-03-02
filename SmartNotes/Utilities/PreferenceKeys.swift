//
//  PreferenceKeys.swift
//  SmartNotes
//
//  Created on 3/10/25.
//

import SwiftUI

struct CoordinatorPreferenceKey: PreferenceKey {
    static var defaultValue: MultiPageUnifiedScrollView.Coordinator?
    
    static func reduce(value: inout MultiPageUnifiedScrollView.Coordinator?, nextValue: () -> MultiPageUnifiedScrollView.Coordinator?) {
        value = value ?? nextValue()
    }
} 