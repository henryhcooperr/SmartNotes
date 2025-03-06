//
//  TemplateSettingsView.swift
//  SmartNotes
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
    
    // Toggle for disabling finger drawing
    @AppStorage("disableFingerDrawing") private var disableFingerDrawing: Bool = false
    
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
                
                // Only show spacing/line config if a template is selected
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
                                selectedType = .lined
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
                
                // Pencil only toggle
                Section(header: Text("Pencil Only")) {
                    Toggle("Disable Finger Drawing", isOn: $disableFingerDrawing)
                }
            }
            .navigationTitle("Template Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Apply") {
                    // Log current vs new template values before applying
                    print("🖌️ Before apply - Current template: \(template.type.rawValue), New selection: \(selectedType.rawValue)")
                    
                    // Apply changes to the template binding
                    applyChanges()
                    print("🖌️ After applyChanges() - Template is now: \(template.type.rawValue)")
                    
                    // Force immediate template refresh with improved three-step approach and more delay between steps
                    DispatchQueue.main.async {
                        print("🖌️ Step 1: Publishing TemplateChanged event with template type: \(template.type.rawValue)")
                        // 1. Publish template changed event with the new template
                        EventBus.shared.publish(TemplateEvents.TemplateChanged(template: template))
                        
                        // 2. Post notification to trigger layoutPages() - longer delay to ensure event is processed first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("🖌️ Step 2: Posting RefreshTemplate notification")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("RefreshTemplate"),
                                object: nil
                            )
                            
                            // 3. Post a second notification after a longer delay to ensure refresh
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                print("🖌️ Step 3: Posting ForceTemplateRefresh notification")
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ForceTemplateRefresh"),
                                    object: nil
                                )
                                
                                // 4. Finally dismiss the sheet after a significant delay to ensure changes are applied
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    print("🖌️ Step 4: Dismissing TemplateSettingsView")
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }
                    }
                }
            )
        }
    }
    
    private func applyChanges() {
        print("📝 Applying template changes: type=\(selectedType.rawValue), spacing=\(spacing), lineWidth=\(lineWidth), color=\(colorHex)")
        print("📝 BEFORE: Current template type=\(template.type.rawValue), spacing=\(template.spacing), lineWidth=\(template.lineWidth)")
        
        // Create a fresh template rather than modifying the existing one
        let newTemplate = CanvasTemplate(
            type: selectedType,
            baseSpacing: CGFloat(spacing),
            colorHex: colorHex,
            baseLineWidth: CGFloat(lineWidth)
        )
        
        // Now copy the values to our binding
        template = newTemplate
        
        print("📝 AFTER: Updated template type=\(template.type.rawValue), spacing=\(template.spacing), lineWidth=\(template.lineWidth)")
        
        // Also publish a debug notification with the raw template data so we can inspect it
        if GlobalSettings.debugModeEnabled {
            if let data = try? JSONEncoder().encode(template) {
                print("📝 Template encoded to \(data.count) bytes")
                if let json = String(data: data, encoding: .utf8) {
                    print("📝 Template JSON: \(json)")
                }
            }
        }
    }
    
    // Convert hex to a color name
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
    
    // A preview of the template lines/dots
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
                        // Horizontal
                        for y in stride(from: gap, to: size.height, by: gap) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        // Vertical
                        for x in stride(from: gap, to: size.width, by: gap) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                    case .dotted:
                        // Dot grid
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
                        break
                    }
                },
                with: .color(Color(color)),
                lineWidth: lineSize
            )
        }
    }
}
