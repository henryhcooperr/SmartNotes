//
//  TemplateSettingsView.swift
//  SmartNotes
//
//  Created on 2/26/25.
//
//  This file provides the UI for configuring note templates.
//  Key responsibilities:
//    - Template type selection (none, lined, graph, dotted)
//    - Spacing, line width, and color configuration
//    - Live preview of template appearance
//    - Quick template presets (college ruled, graph paper)
//    - Applying changes to the active note
//
//  This view appears as a sheet when the template settings
//  button is tapped in NoteDetailView.
//

import SwiftUI

struct TemplateSettingsView: View {
    @Binding var template: CanvasTemplate
    @Environment(\.presentationMode) var presentationMode
    
    // Temporary state for editing
    @State private var selectedType: CanvasTemplate.TemplateType
    @State private var spacing: Double
    @State private var lineWidth: Double
    @State private var colorHex: String
    
    // Available colors
    let colorOptions = [
        "#CCCCCC", // Light gray
        "#000000", // Black
        "#0000FF", // Blue
        "#FF0000", // Red
        "#00FF00"  // Green
    ]
    
    init(template: Binding<CanvasTemplate>) {
        self._template = template
        self._selectedType = State(initialValue: template.wrappedValue.type)
        self._spacing = State(initialValue: Double(template.wrappedValue.spacing))
        self._lineWidth = State(initialValue: Double(template.wrappedValue.lineWidth))
        self._colorHex = State(initialValue: template.wrappedValue.colorHex)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Template type picker
                Section(header: Text("Template Type")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(CanvasTemplate.TemplateType.allCases) { type in
                            Label(type.rawValue, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Only show spacing settings if a template is selected
                if selectedType != .none {
                    Section(header: Text("Line Spacing")) {
                        HStack {
                            Text("Spacing: \(Int(spacing)) pts")
                            Spacer()
                            Slider(value: $spacing, in: 10...50, step: 2)
                                .frame(width: 180)
                        }
                    }
                    
                    Section(header: Text("Line Style")) {
                        HStack {
                            Text("Thickness: \(lineWidth, specifier: "%.1f") pt")
                            Spacer()
                            Slider(value: $lineWidth, in: 0.25...2.0, step: 0.25)
                                .frame(width: 180)
                        }
                        
                        Picker("Color", selection: $colorHex) {
                            ForEach(colorOptions, id: \.self) { hex in
                                HStack {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(UIColor(hex: hex) ?? .gray))
                                        .frame(width: 20, height: 20)
                                    Text(colorName(for: hex))
                                        .tag(hex)
                                }
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Section(header: Text("Preview")) {
                        templatePreview
                            .frame(height: 100)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.vertical, 8)
                    }
                    
                    // Quick presets
                    Section(header: Text("Presets")) {
                        HStack {
                            Button("College Ruled") {
                                spacing = 24
                                lineWidth = 0.5
                                colorHex = "#CCCCCC"
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("Graph Paper") {
                                selectedType = .graph
                                spacing = 20
                                lineWidth = 0.5
                                colorHex = "#CCCCCC"
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Template Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Apply") {
                    applyChanges()
                    
                    // This is a key addition - we post a notification before dismissing
                    // to force immediate template refresh
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RefreshTemplate"),
                            object: nil
                        )
                        
                        // Give the notification a moment to be processed before dismissing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            )
        }
    }
    
    private func applyChanges() {
        print("📝 Applying template changes: type=\(selectedType.rawValue), spacing=\(spacing), lineWidth=\(lineWidth), color=\(colorHex)")
        template.type = selectedType
        template.spacing = CGFloat(spacing)
        template.lineWidth = CGFloat(lineWidth)
        template.colorHex = colorHex
    }
    
    // Helper to convert hex to color name
    private func colorName(for hex: String) -> String {
        switch hex {
        case "#CCCCCC": return "Light Gray"
        case "#000000": return "Black"
        case "#0000FF": return "Blue"
        case "#FF0000": return "Red"
        case "#00FF00": return "Green"
        default: return "Custom"
        }
    }
    
    // A preview of the template
    private var templatePreview: some View {
        Canvas { context, size in
            let color = UIColor(hex: colorHex) ?? .lightGray
            let lineSize = CGFloat(lineWidth)
            let gap = CGFloat(spacing)
            
            context.stroke(
                Path { path in
                    switch selectedType {
                    case .lined:
                        // Draw horizontal lines
                        for y in stride(from: gap, to: size.height, by: gap) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        
                    case .graph:
                        // Draw horizontal lines
                        for y in stride(from: gap, to: size.height, by: gap) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        
                        // Draw vertical lines
                        for x in stride(from: gap, to: size.width, by: gap) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        
                    case .dotted:
                        // Draw dots at intersections
                        for y in stride(from: gap, to: size.height, by: gap) {
                            for x in stride(from: gap, to: size.width, by: gap) {
                                let rect = CGRect(
                                    x: x - lineSize,
                                    y: y - lineSize,
                                    width: lineSize * 2,
                                    height: lineSize * 2
                                )
                                path.addEllipse(in: rect)
                            }
                        }
                        
                    case .none:
                        // No template
                        break
                    }
                },
                with: .color(Color(color)),
                lineWidth: lineSize
            )
        }
    }
}
