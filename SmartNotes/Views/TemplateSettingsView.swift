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
        // Use baseSpacing and baseLineWidth directly to avoid resolution factor multiplication
        self._spacing = State(initialValue: Double(template.wrappedValue.baseSpacing))
        self._lineWidth = State(initialValue: Double(template.wrappedValue.baseLineWidth))
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
                            Slider(value: $spacing, in: 4...25, step: 1)
                                .frame(width: 180)
                        }
                    }
                    
                    Section(header: Text("Line Style")) {
                        HStack {
                            Text("Thickness: \(lineWidth, specifier: "%.2f") pt")
                            Spacer()
                            Slider(value: $lineWidth, in: 0.1...2.0, step: 0.05)
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
                        
                        HStack {
                            Button("Fine Grid") {
                                selectedType = .graph
                                spacing = 8
                                lineWidth = 0.2
                                colorHex = "#CCCCCC"
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("Fine Dots") {
                                selectedType = .dotted
                                spacing = 10
                                lineWidth = 0.2
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
            
            switch selectedType {
            case .lined:
                // Calculate how many lines we can fit and center them
                let totalLines = Int(size.height / gap)
                let remainingSpace = size.height - (CGFloat(totalLines) * gap)
                let offsetY = remainingSpace / 2
                
                for i in 0...totalLines {
                    let y = offsetY + (CGFloat(i) * gap)
                    if y >= 0 && y <= size.height {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                            },
                            with: .color(Color(color)),
                            lineWidth: lineSize
                        )
                    }
                }
                
            case .graph:
                // Calculate offsets for horizontal and vertical lines
                let totalHLines = Int(size.height / gap)
                let remainingHSpace = size.height - (CGFloat(totalHLines) * gap)
                let offsetY = remainingHSpace / 2
                
                let totalVLines = Int(size.width / gap)
                let remainingVSpace = size.width - (CGFloat(totalVLines) * gap)
                let offsetX = remainingVSpace / 2
                
                // Draw horizontal lines (centered)
                for i in 0...totalHLines {
                    let y = offsetY + (CGFloat(i) * gap)
                    if y >= 0 && y <= size.height {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                            },
                            with: .color(Color(color)),
                            lineWidth: lineSize
                        )
                    }
                }
                
                // Draw vertical lines (centered)
                for i in 0...totalVLines {
                    let x = offsetX + (CGFloat(i) * gap)
                    if x >= 0 && x <= size.width {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            },
                            with: .color(Color(color)),
                            lineWidth: lineSize
                        )
                    }
                }
                
            case .dotted:
                // Calculate offsets for rows and columns of dots
                let totalRows = Int(size.height / gap)
                let remainingVSpace = size.height - (CGFloat(totalRows) * gap)
                let offsetY = remainingVSpace / 2
                
                let totalCols = Int(size.width / gap)
                let remainingHSpace = size.width - (CGFloat(totalCols) * gap)
                let offsetX = remainingHSpace / 2
                
                // Draw dots at intersections (centered grid)
                for row in 0...totalRows {
                    let y = offsetY + (CGFloat(row) * gap)
                    if y >= 0 && y <= size.height {
                        for col in 0...totalCols {
                            let x = offsetX + (CGFloat(col) * gap)
                            if x >= 0 && x <= size.width {
                                context.fill(
                                    Path { path in
                                        let rect = CGRect(
                                            x: x - lineSize,
                                            y: y - lineSize,
                                            width: lineSize * 2,
                                            height: lineSize * 2
                                        )
                                        path.addEllipse(in: rect)
                                    },
                                    with: .color(Color(color))
                                )
                            }
                        }
                    }
                }
                
            case .none:
                break
            }
        }
    }
}
