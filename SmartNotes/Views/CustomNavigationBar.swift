//
//  CustomNavigationBar.swift
//  SmartNotes
//
//  Created on 4/9/25.
//

import SwiftUI

struct CustomNavigationBar: View {
    @Binding var title: String
    let onBack: () -> Void
    let onToggleSidebar: () -> Void
    let onShowTemplateSettings: () -> Void
    let onShowExport: () -> Void
    let onTitleChanged: ((String) -> Void)?
    
    init(title: Binding<String>, 
         onBack: @escaping () -> Void,
         onToggleSidebar: @escaping () -> Void,
         onShowTemplateSettings: @escaping () -> Void,
         onShowExport: @escaping () -> Void,
         onTitleChanged: ((String) -> Void)? = nil) {
        self._title = title
        self.onBack = onBack
        self.onToggleSidebar = onToggleSidebar
        self.onShowTemplateSettings = onShowTemplateSettings
        self.onShowExport = onShowExport
        self.onTitleChanged = onTitleChanged
    }
    
    var body: some View {
        HStack {
            // Left
            HStack(spacing: 12) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.primary)
                    .contentShape(Rectangle())
                }
                
                Button(action: onToggleSidebar) {
                    Image(systemName: "sidebar.leading")
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Center - Editable title
            TextField("Note Title", text: $title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .onChange(of: title) { _, newValue in
                    onTitleChanged?(newValue)
                }
            
            Spacer()
            
            // Right
            HStack(spacing: 20) {
                Button(action: onShowTemplateSettings) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                }
                
                Button(action: onShowExport) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

struct CustomNavigationBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            CustomNavigationBar(
                title: .constant("Note Title"),
                onBack: { },
                onToggleSidebar: { },
                onShowTemplateSettings: { },
                onShowExport: { }
            )
            Spacer()
        }
        .previewLayout(.sizeThatFits)
    }
} 