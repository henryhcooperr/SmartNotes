//
//  EnhancedNoteCardView.swift
//  SmartNotes
//
//  Created on 3/7/25
//
//  This file provides an enhanced version of the note card view
//  with more visual polish, animations, and dynamic previews.
//  Key features:
//    - Dynamic thumbnail generation with multi-page preview
//    - Animated hover effects and transitions
//    - Support for various card sizes and layouts
//    - Integration with the template system
//    - Quick action buttons for common operations
//

import SwiftUI
import PencilKit

struct EnhancedNoteCardView: View {
    let note: Note
    let subject: Subject
    let style: CardStyle
    
    // Optional callbacks for actions
    var onOpen: (() -> Void)?
    var onRename: (() -> Void)?
    var onShare: (() -> Void)?
    var onDelete: (() -> Void)?
    
    // View states
    @State private var isHovering = false
    @State private var showQuickActions = false
    @State private var showingNavigationLink = false
    
    // Card style options
    enum CardStyle {
        case large   // Big grid item
        case medium  // Medium list item
        case small   // Compact list item
        case spotlight // Featured item
    }
    
    // Navigation link reference for opening the note
    @State private var navigationLinkActive = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Base card
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail area
                thumbnailArea
                
                // Title and info
                infoArea
            }
            .background(
                RoundedRectangle(cornerRadius: style == .spotlight ? 16 : 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(isHovering ? 0.15 : 0.1), radius: isHovering ? 8 : 4, y: isHovering ? 4 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: style == .spotlight ? 16 : 12)
                    .stroke(Color.accentColor.opacity(isHovering ? 0.5 : 0), lineWidth: 2)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                    showQuickActions = hovering && (style == .large || style == .spotlight)
                }
            }
            .onTapGesture {
                if let onOpen = onOpen {
                    onOpen()
                } else {
                    showingNavigationLink = true
                }
            }
            
            // Quick action buttons
            if showQuickActions {
                HStack(spacing: 8) {
                    quickActionButton(iconName: "pencil", action: onRename)
                    quickActionButton(iconName: "square.and.arrow.up", action: onShare)
                    quickActionButton(iconName: "trash", action: onDelete)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Material.ultraThinMaterial)
                )
                .padding(8)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Hidden NavigationLink for opening the note
            NavigationLink(
                destination: NoteDetailView(
                    note: .constant(note),
                    subjectID: subject.id
                ),
                isActive: $showingNavigationLink
            ) {
                EmptyView()
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: showQuickActions)
    }
    
    // MARK: - Components
    
    private var thumbnailArea: some View {
        ZStack(alignment: .bottomTrailing) {
            // Page preview
            notePreview
                .frame(height: thumbnailHeight)
                .clipShape(
                    RoundedRectangle(cornerRadius: style == .spotlight ? 16 : 12,
                                     style: .continuous)
                )
            
            // Page count indicator
            if note.pages.count > 1 {
                ZStack {
                    Capsule()
                        .fill(Material.ultraThinMaterial)
                        .frame(width: 36, height: 22)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("\(note.pages.count)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.primary)
                }
                .padding(8)
            }
            
            // Template indicator
            if note.noteTemplate != nil && note.noteTemplate?.type != .none {
                templateIndicator
                    .padding(note.pages.count > 1 ? 8 : 8)
                    .padding(.trailing, note.pages.count > 1 ? 40 : 8)
            }
        }
    }
    
    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(titleFont)
                .fontWeight(.medium)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            // Date and metadata
            HStack {
                Text(note.lastModified, format: dateFormat)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                // Subject label
                if style != .small {
                    Text(subject.name)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundColor(.white)
                        .background(subject.color)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
    
    private var templateIndicator: some View {
        let templateType: String
        
        if let template = note.noteTemplate {
            switch template.type {
            case .lined: templateType = "doc.text"
            case .graph: templateType = "square.grid.2x2"
            case .dotted: templateType = "circle.grid.2x2"
            case .none: templateType = ""
            }
        } else {
            templateType = ""
        }
        
        return ZStack {
            Circle()
                .fill(Material.ultraThinMaterial)
                .frame(width: 24, height: 24)
            
            Image(systemName: templateType)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
    }
    
    private func quickActionButton(iconName: String, action: (() -> Void)?) -> some View {
        Button(action: {
            if let action = action {
                action()
            }
        }) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Note Preview
    
    private var notePreview: some View {
        Group {
            if hasValidPreviewContent {
                generatePreviewFromPage()
            } else {
                emptyNotePreview
            }
        }
    }
    
    private var hasValidPreviewContent: Bool {
        // Check if there's page data to render
        if !note.pages.isEmpty, let firstPage = note.pages.first, !firstPage.drawingData.isEmpty {
            return true
        }
        
        // Fallback to legacy note data
        if !note.drawingData.isEmpty {
            return true
        }
        
        return false
    }
    
    private func generatePreviewFromPage() -> some View {
        let previewImage: UIImage
        let hasTemplate = note.noteTemplate != nil && note.noteTemplate?.type != .none
        
        // Standard page size
        let pageSize = CGSize(width: 612, height: 792)
        
        // Try to get image from first page
        if !note.pages.isEmpty, let firstPage = note.pages.first, !firstPage.drawingData.isEmpty {
            if let drawing = try? PKDrawing(data: firstPage.drawingData) {
                // Create an image from the drawing with appropriate scale
                previewImage = drawing.image(from: CGRect(origin: .zero, size: pageSize), scale: 0.5)
            } else {
                previewImage = UIImage()
            }
        }
        // Fallback to legacy note data
        else if !note.drawingData.isEmpty, let drawing = try? PKDrawing(data: note.drawingData) {
            previewImage = drawing.image(from: CGRect(origin: .zero, size: pageSize), scale: 0.5)
        } else {
            previewImage = UIImage()
        }
        
        return ZStack {
            // Background color or template
            Rectangle()
                .fill(Color.white)
            
            // If template exists, show a subtle pattern
            if hasTemplate {
                templatePatternView
            }
            
            // Drawing content
            if previewImage.size.width > 0 {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            }
        }
    }
    
    private var emptyNotePreview: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.white)
            
            // Template pattern if present
            if note.noteTemplate != nil && note.noteTemplate?.type != .none {
                templatePatternView
            }
            
            // Empty state indicator
            VStack(spacing: 8) {
                Image(systemName: "square.text.square")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.4))
                
                Text("Empty Note")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var templatePatternView: some View {
            Group {
                if let template = note.noteTemplate {
                    switch template.type {
                    case .lined:
                        // Lined paper pattern
                        HStack(spacing: 0) {
                            VStack(spacing: 20) {
                                ForEach(0..<10, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 1)
                                }
                            }
                            .padding(.top, 20)
                        }
                    
                    case .graph:
                        // Graph paper pattern
                        ZStack {
                            // Horizontal lines
                            VStack(spacing: 20) {
                                ForEach(0..<10, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 0.5)
                                }
                            }
                            
                            // Vertical lines
                            HStack(spacing: 20) {
                                ForEach(0..<10, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 0.5)
                                }
                            }
                        }
                    
                    case .dotted:
                        // Dotted paper pattern
                        ZStack {
                            ForEach(0..<5, id: \.self) { row in
                                HStack(spacing: 20) {
                                    ForEach(0..<5, id: \.self) { col in
                                        Circle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 3, height: 3)
                                    }
                                }
                                .offset(y: CGFloat(row) * 20)
                            }
                        }
                    
                    case .none:
                        // No pattern for none template
                        EmptyView()
                    }
                } else {
                    // No template
                    EmptyView()
                }
            }
        }
    
    // MARK: - Computed Properties
    
    private var thumbnailHeight: CGFloat {
        switch style {
        case .large: return 180
        case .medium: return 120
        case .small: return 80
        case .spotlight: return 220
        }
    }
    
    private var titleFont: Font {
        switch style {
        case .large, .spotlight: return .headline
        case .medium: return .subheadline
        case .small: return .caption
        }
    }
    
    private var dateFormat: Date.FormatStyle {
        switch style {
        case .large, .spotlight:
            return .dateTime.month().day().year()
        case .medium:
            return .dateTime.month().day()
        case .small:
            return .dateTime.month(.abbreviated).day()
        }
    }
}

// MARK: - Preview Provider

struct EnhancedNoteCardView_Previews: PreviewProvider {
    static var previews: some View {
        let subject = Subject(name: "Math Notes", notes: [], colorName: "blue")
        let emptyNote = Note(title: "Empty Note", drawingData: Data())
        
        let template = CanvasTemplate(type: .lined, spacing: 24, colorHex: "#CCCCCC")
        var templateNote = Note(title: "Note with Template", drawingData: Data())
        templateNote.noteTemplate = template
        
        return Group {
            EnhancedNoteCardView(note: emptyNote, subject: subject, style: .large)
                .frame(width: 250)
                .padding()
                .previewDisplayName("Large Empty")
            
            EnhancedNoteCardView(note: templateNote, subject: subject, style: .medium)
                .frame(width: 350)
                .padding()
                .previewDisplayName("Medium with Template")
            
            EnhancedNoteCardView(note: emptyNote, subject: subject, style: .small)
                .frame(width: 300)
                .padding()
                .previewDisplayName("Small")
            
            EnhancedNoteCardView(note: templateNote, subject: subject, style: .spotlight)
                .frame(width: 300)
                .padding()
                .previewDisplayName("Spotlight")
        }
        .previewLayout(.sizeThatFits)
    }
}
