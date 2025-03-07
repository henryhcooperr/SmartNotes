//
//  TemplateSettingsView.swift
//  SmartNotes
//
//  Updated on 5/6/25 to use EventStore instead of direct bindings
//

import SwiftUI

struct TemplateSettingsView: View {
    // Access to the EventStore
    @EnvironmentObject var eventStore: EventStore
    @Environment(\.presentationMode) var presentationMode
    
    // Note and template identification
    let noteID: UUID?
    let subjectID: UUID?
    
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
    
    init(noteID: UUID?, subjectID: UUID?, currentTemplate: CanvasTemplate) {
        self.noteID = noteID
        self.subjectID = subjectID
        self._selectedType = State(initialValue: currentTemplate.type)
        // Use baseSpacing and baseLineWidth directly to avoid resolution factor multiplication
        self._spacing = State(initialValue: Double(currentTemplate.baseSpacing))
        self._lineWidth = State(initialValue: Double(currentTemplate.baseLineWidth))
        self._colorHex = State(initialValue: currentTemplate.colorHex)
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
                
                // Template properties
                if selectedType != .none && selectedType != .blank {
                    Section(header: Text("Properties")) {
                        // Line spacing
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Spacing: \(Int(spacing))")
                                Spacer()
                                Text(getReadableSpacingDescription())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $spacing, in: getSpacingRange())
                        }
                        
                        // Line color
                        VStack(alignment: .leading) {
                            Text("Line Color")
                            
                            HStack {
                                ForEach(colorOptions, id: \.self) { color in
                                    let swiftUIColor = colorFromHex(color)
                                    Circle()
                                        .fill(swiftUIColor)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(color == colorHex ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            colorHex = color
                                        }
                                }
                            }
                        }
                        
                        // Line width
                        VStack(alignment: .leading) {
                            Text("Line Width: \(String(format: "%.1f", lineWidth))")
                            
                            Slider(value: $lineWidth, in: 0.1...2.0, step: 0.1)
                        }
                        
                        // Presets
                        Text("Presets").bold()
                        
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
                        .onChange(of: disableFingerDrawing) { _, newValue in
                            // Dispatch action to update the setting in EventStore
                            eventStore.dispatch(SettingsAction.updateFingerDrawingSetting(isDisabled: newValue))
                        }
                }
            }
            .navigationTitle("Template Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Apply") {
                    // Log current vs new template values before applying
                    print("🖌️ Before apply - Selected template type: \(selectedType.rawValue)")
                    
                    // Create the new template
                    let newTemplate = createUpdatedTemplate()
                    
                    // Apply either as a note-wide or default template
                    if let noteID = noteID, let subjectID = subjectID {
                        // Apply as a note template
                        applyNoteTemplate(noteID: noteID, subjectID: subjectID, template: newTemplate)
                    } else {
                        // Apply as a default template
                        applyDefaultTemplate(template: newTemplate)
                    }
                    
                    // Dismiss the view
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a new template with the current settings
    private func createUpdatedTemplate() -> CanvasTemplate {
        return CanvasTemplate(
            type: selectedType,
            baseSpacing: CGFloat(spacing),
            baseLineWidth: CGFloat(lineWidth),
            colorHex: colorHex
        )
    }
    
    /// Apply the template to a specific note
    private func applyNoteTemplate(noteID: UUID, subjectID: UUID, template: CanvasTemplate) {
        // Dispatch action to set the note template
        eventStore.dispatch(TemplateAction.setNoteTemplate(
            template,
            noteID: noteID,
            subjectID: subjectID
        ))
        
        print("🖌️ Applied template to note \(noteID) with type: \(template.type.rawValue)")
    }
    
    /// Apply the template as the default for new notes
    private func applyDefaultTemplate(template: CanvasTemplate) {
        // Dispatch action to set the default template
        eventStore.dispatch(TemplateAction.setDefaultTemplate(template))
        
        print("🖌️ Applied template as default with type: \(template.type.rawValue)")
    }
    
    /// Get a readable description of the current spacing
    private func getReadableSpacingDescription() -> String {
        switch selectedType {
        case .lined:
            if spacing < 15 {
                return "Narrow"
            } else if spacing < 25 {
                return "Medium"
            } else {
                return "Wide"
            }
        case .graph, .dotted:
            if spacing < 10 {
                return "Fine"
            } else if spacing < 20 {
                return "Medium"
            } else {
                return "Large"
            }
        default:
            return ""
        }
    }
    
    /// Get the appropriate spacing range based on template type
    private func getSpacingRange() -> ClosedRange<Double> {
        switch selectedType {
        case .lined:
            return 10.0...40.0
        case .graph, .dotted:
            return 5.0...40.0
        default:
            return 10.0...40.0
        }
    }
    
    /// Convert a hex color to a SwiftUI color
    private func colorFromHex(_ hex: String) -> Color {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }
        
        if hexString.count != 6 {
            return .gray
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        
        return Color(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
