//
//  CustomNavigationBar.swift
//  SmartNotes
//
//  Created on 4/9/25.
//

import SwiftUI

struct CustomNavigationBar: View {
    let title: String
    let onBack: () -> Void
    let onToggleSidebar: () -> Void
    let onShowTemplateSettings: () -> Void
    let onShowExport: () -> Void
    
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
            
            // Center
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            
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
                title: "Note Title",
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