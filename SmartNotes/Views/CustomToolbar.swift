//
//  CustomToolbar.swift
//  SmartNotes
//
//  Created on 3/10/25.
//
//  This file defines a custom toolbar for drawing tools and actions.
//  It provides a consistent UI for tool selection while still using
//  PencilKit's underlying functionality.
//

import SwiftUI
import PencilKit

struct CustomToolbar: View {
    // The coordinator that manages all canvas views
    let coordinator: MultiPageUnifiedScrollView.Coordinator?
    
    // Selected tool state
    @Binding var selectedTool: PKInkingTool.InkType
    @Binding var selectedColor: Color
    @Binding var lineWidth: CGFloat
    
    // Tool visibility
    @State private var showColorPicker = false
    @State private var showWidthPicker = false
    
    // Currently selected tool type
    @State private var isEraserSelected = false
    
    // Customization mode
    @State private var isCustomizing = false
    @State private var toolbarPosition: ToolbarPosition = .bottom
    @State private var dragOffset = CGSize.zero
    
    // Long press timer
    @State private var longPressTimer: Timer?
    @State private var isLongPressing = false
    
    // Animation properties
    @State private var wiggleAmount = 0.0
    
    // User tools configuration (stored in UserDefaults)
    @State private var tools: [DrawingTool] = [
        DrawingTool(type: .pen),
        DrawingTool(type: .pencil),
        DrawingTool(type: .marker),
        DrawingTool(type: .eraser),
        DrawingTool(type: .selection),
        DrawingTool(type: .aiTool),
        DrawingTool(type: .undo),
        DrawingTool(type: .redo)
    ]
    
    // Available colors
    @State private var colors: [Color] = [
        // Use explicitly defined RGB colors instead of semantic color names
        Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1),          // black
        Color(.sRGB, red: 0, green: 0, blue: 1, opacity: 1),          // blue
        Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1),          // red
        Color(.sRGB, red: 0, green: 0.5, blue: 0, opacity: 1),        // green
        Color(.sRGB, red: 1, green: 0.5, blue: 0, opacity: 1),        // orange
        Color(.sRGB, red: 0.5, green: 0, blue: 0.5, opacity: 1)       // purple
    ]
    
    // Available line widths
    @State private var lineWidths: [CGFloat] = [1, 2, 4, 6, 10]
    
    // Add these state variables to CustomToolbar
    @State private var draggedTool: DrawingTool?
    @State private var draggedToolLocation: CGPoint?
    
    // New animation timer
    @State private var wiggleTimer: Timer?
    
    // Add a state to track which tool is showing size options
    @State private var toolShowingWidthOptions: DrawingTool.ToolType?
    
    // 1. First, add a state to track the position of the selected tool
    @State private var activeToolFrame: CGRect = .zero
    
    // 2. Add state for custom width/color UI
    @State private var showCustomWidthInput = false
    @State private var showCustomColorPicker = false
    @State private var tempCustomWidth: CGFloat = 5.0
    @State private var tempCustomColor: Color = .gray
    
    // New state for color picker index
    @State private var showColorPickerForIndex: Int? = nil
    
    // Add a state variable to track if we're in the "no tool selected" state
    @State private var noToolSelected = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                toolbarContent(geometry: geometry)
                    .offset(dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                self.dragOffset = value.translation
                            }
                            .onEnded { value in
                                // Calculate final position
                                let finalX = value.location.x
                                let finalY = value.location.y
                                
                                // Find nearest edge
                                let newPosition = ToolbarPosition.nearest(
                                    to: CGPoint(x: finalX, y: finalY),
                                    in: geometry
                                )
                                
                                // Apply with animation
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    self.dragOffset = .zero
                                    self.toolbarPosition = newPosition
                                }
                                
                                // Save preference
                                saveToolbarPosition()
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 1.5)
                            .onChanged { isPressing in
                                self.isLongPressing = isPressing
                                if isPressing {
                                    startLongPressTimer()
                                } else {
                                    cancelLongPressTimer()
                                }
                            }
                            .onEnded { _ in
                                enterCustomizationMode()
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: toolbarPosition.alignment)
        }
        .onAppear {
            print("🖋️ CustomToolbar: onAppear called")
            
            // Load saved preferences but don't apply any tool
            loadSavedPreferences()
            loadCustomSettings()
            
            // Clear tool selection - set to neutral state
            selectedTool = .pen  // Default type, but we won't apply it
            isEraserSelected = false
            noToolSelected = true
            
            // Use CanvasManager to clear any tool selection
            CanvasManager.shared.clearToolSelection()
            
            print("🖋️ CustomToolbar: Initialized with no active tool")
        }
        .onDisappear {
            cancelLongPressTimer()
            wiggleTimer?.invalidate()
            wiggleTimer = nil
        }
    }
    
    // MARK: - Toolbar Content Based on Position
    
    private func toolbarContent(geometry: GeometryProxy) -> some View {
        Group {
            if toolbarPosition.isVertical {
                HStack(spacing: 0) {
                    // For right toolbar, show picker on the left
                    if toolbarPosition == .right, let toolType = toolShowingWidthOptions {
                        sideWidthPicker(for: toolType)
                            .frame(width: 90) // Increased width for colors
                    }
                    
                    // Main vertical toolbar
                    verticalToolbar()
                    
                    // For left toolbar, show picker on the right
                    if toolbarPosition == .left, let toolType = toolShowingWidthOptions {
                        sideWidthPicker(for: toolType)
                            .frame(width: 90) // Increased width for colors
                    }
                }
                // Update max width for the entire toolbar
                .frame(maxWidth: toolShowingWidthOptions != nil ? 180 : 80)
            } else {
                VStack(spacing: 0) {
                    // Extended picker (above if bottom toolbar)
                    if let toolType = toolShowingWidthOptions, toolbarPosition == .bottom {
                        horizontalWidthPicker(for: toolType)
                            .frame(height: 120) // Increased height for colors
                    }
                    
                    // Main horizontal toolbar
                    horizontalToolbar()
                    
                    // Extended picker (below if top toolbar)
                    if let toolType = toolShowingWidthOptions, toolbarPosition == .top {
                        horizontalWidthPicker(for: toolType)
                            .frame(height: 120) // Increased height for colors
                    }
                }
                // Update max height for the entire toolbar
                .frame(maxHeight: toolShowingWidthOptions != nil ? 210 : 80)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .fixedSize()
        .animation(.spring(response: 0.3), value: toolShowingWidthOptions)
    }
    
    private func horizontalToolbar() -> some View {
        HStack(spacing: 16) {
            ForEach(tools) { tool in
                Button {
                    if !isCustomizing {
                        handleToolTap(tool)
                    }
                } label: {
                    Image(systemName: tool.type.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(getColorForTool(tool))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(getBackgroundForTool(tool))
                        )
                }
                // Observe position of the button for width picker placement
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ViewPositionKey.self, value: 
                                toolShowingWidthOptions == tool.type ? geo.frame(in: .global) : .zero
                            )
                    }
                )
            }
            
            if showColorPicker {
                colorPickerPanel()
            }
        }
        .padding()
        .onPreferenceChange(ViewPositionKey.self) { frame in
            if frame != .zero {
                self.activeToolFrame = frame
            }
        }
    }
    
    private func toolItemWithOptions(for tool: DrawingTool, at index: Int) -> some View {
        VStack(spacing: 8) {
            if isCustomizing {
                customizationControls(for: index)
            }
            
            toolButton(for: tool)
                .onTapGesture {
                    if !isCustomizing {
                        handleToolTap(tool)
                        print("👆 Tapped on tool: \(tool.type)")
                    }
                }
            
            if toolShowingWidthOptions == tool.type {
                Text("Width picker should be visible")
                    .font(.system(size: 8))
                    .foregroundColor(.red)
                    .hidden()
                
                contextualWidthPicker(for: tool.type)
                    .id("\(tool.id)-width-picker")
                    .zIndex(10)
            }
        }
        .padding(.bottom, toolShowingWidthOptions == tool.type ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toolShowingWidthOptions)
    }
    
    private func customizationControls(for index: Int) -> some View {
        HStack {
            if index > 0 {
                Button(action: {
                    moveToolInArray(from: index, to: index - 1)
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 10))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            Spacer()
            
            if index < tools.count - 1 {
                Button(action: {
                    moveToolInArray(from: index, to: index + 1)
                }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .frame(width: 40)
        .padding(.bottom, 2)
    }
    
    private func toggleWidthOptions(for toolType: DrawingTool.ToolType) {
        print("🔍 Toggling width options for: \(toolType)")
        
        if toolType.requiresWidth {
            if toolShowingWidthOptions == toolType {
                toolShowingWidthOptions = nil
                print("📊 Hiding width options")
            } else {
                toolShowingWidthOptions = toolType
                print("📊 Showing width options for \(toolType)")
            }
        } else {
            toolShowingWidthOptions = nil
            print("📊 Tool doesn't require width options")
        }
    }
    
    private func verticalToolbar() -> some View {
        VStack(spacing: 16) {
            ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                toolButton(for: tool)
                    .rotationEffect(Angle(degrees: isCustomizing ? wiggleAmount * (index.isMultiple(of: 2) ? 1 : -1) : 0))
                    .opacity(draggedTool?.id == tool.id && isCustomizing ? 0.5 : 1.0)
                    .overlay(
                        isCustomizing ? 
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 2)
                            .opacity(0.5)
                        : nil
                    )
                    .gesture(
                        isCustomizing ?
                        DragGesture()
                            .onChanged { gesture in
                                if draggedTool == nil {
                                    self.draggedTool = tool
                                    self.draggedToolLocation = gesture.location
                                }
                                self.draggedToolLocation = gesture.location
                            }
                            .onEnded { gesture in
                                // Find the index to drop at
                                if let draggedTool = draggedTool,
                                   let fromIndex = tools.firstIndex(where: { $0.id == draggedTool.id }),
                                   let toIndex = getDropIndex(at: gesture.location) {
                                    
                                    // Reorder the tools
                                    withAnimation(.spring()) {
                                        let movedItem = tools[fromIndex]
                                        tools.remove(at: fromIndex)
                                        tools.insert(movedItem, at: toIndex)
                                    }
                                }
                                
                                self.draggedTool = nil
                                self.draggedToolLocation = nil
                            }
                        : nil
                    )
            }
            
            if showColorPicker {
                colorPickerPanel()
            }
        }
        .padding(.vertical)
        .overlay(
            draggedTool != nil && draggedToolLocation != nil ?
            toolButton(for: draggedTool!)
                .position(draggedToolLocation!)
                .opacity(0.8)
            : nil
        )
    }
    
    // MARK: - Tool Buttons
    
    private func toolButton(for tool: DrawingTool) -> some View {
        Button {
            if !isCustomizing {
                handleToolTap(tool)
            }
        } label: {
            Image(systemName: tool.type.iconName)
                .font(.system(size: 20))
                .foregroundColor(getColorForTool(tool))
                .padding(8)
                .background(
                    Circle()
                        .fill(getBackgroundForTool(tool))
                )
                .overlay(
                    Group {
                        if isCustomizing {
                            Circle()
                                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                                .scaleEffect(1.1)
                        }
                        if tool.type == .selection || tool.type == .aiTool {
                            Circle()
                                .strokeBorder(Color.purple.opacity(0.6), lineWidth: 2)
                                .padding(2)
                        }
                    }
                )
        }
        .disabled(isCustomizing)
    }
    
    private func getColorForTool(_ tool: DrawingTool) -> Color {
        // If no tool is selected, everything should be gray
        if noToolSelected {
            return .gray
        }
        
        switch tool.type {
        case .pen where selectedTool == .pen && !isEraserSelected:
            return selectedColor
        case .pencil where selectedTool == .pencil && !isEraserSelected:
            return selectedColor
        case .marker where selectedTool == .marker && !isEraserSelected:
            return selectedColor
        case .eraser where isEraserSelected:
            return .red
        case .selection:
            return .purple
        case .aiTool:
            return .blue
        default:
            return .gray
        }
    }
    
    private func getBackgroundForTool(_ tool: DrawingTool) -> Color {
        // If no tool is selected, no background highlighting
        if noToolSelected {
            return Color.clear
        }
        
        if tool.type.requiresWidth && toolShowingWidthOptions == tool.type {
            // Highlight tools that have their width options showing
            return Color.blue.opacity(0.3)
        } else if isToolSelected(tool) {
            return Color.gray.opacity(0.2)
        } else if tool.type == .selection || tool.type == .aiTool {
            return Color.purple.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    // Add this helper method to check if a tool is selected
    private func isToolSelected(_ tool: DrawingTool) -> Bool {
        switch tool.type {
        case .pen:
            return selectedTool == .pen && !isEraserSelected
        case .pencil:
            return selectedTool == .pencil && !isEraserSelected
        case .marker:
            return selectedTool == .marker && !isEraserSelected
        case .eraser:
            return isEraserSelected
        default:
            return false
        }
    }
    
    // MARK: - Tool Picker Panels
    
    private func colorPickerPanel() -> some View {
        HStack(spacing: 12) {
            ForEach(colors, id: \.self) { color in
                Button {
                    selectedColor = color
                    if !isEraserSelected {
                        applyToolWithCanvasManager()
                        // Tool settings are saved in applyToolWithCanvasManager
                    }
                } label: {
                    Circle()
                        .fill(renderAccurateColor(color))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                        )
                }
            }
            
            if toolShowingWidthOptions != nil {
                VStack {
                    Text("Preview")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // A small canvas that demonstrates exactly how the stroke will look
                    ZStack {
                        Color.white
                            .frame(width: 60, height: 40)
                            .cornerRadius(6)
                        
                        // Draw a sample stroke in the EXACT way it will appear on canvas
                        Path { path in
                            path.move(to: CGPoint(x: 10, y: 20))
                            path.addCurve(
                                to: CGPoint(x: 50, y: 20),
                                control1: CGPoint(x: 20, y: 10),
                                control2: CGPoint(x: 40, y: 30)
                            )
                        }
                        .stroke(selectedColor, lineWidth: lineWidth)
                        .frame(width: 60, height: 40)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .transition(.scale.combined(with: .opacity))
    }
    
    private func contextualWidthPicker(for toolType: DrawingTool.ToolType) -> some View {
        VStack {
            Text("SELECT WIDTH")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(lineWidths, id: \.self) { width in
                    Button {
                        self.lineWidth = width
                        applyToolWithCanvasManager()
                    } label: {
                        Circle()
                            .fill(width == lineWidth ? Color.white : Color.gray)
                            .frame(width: width * 4, height: width * 4)
                    }
                    .frame(width: 44, height: 44)  // Larger tap target
                    .background(
                        Circle()
                            .fill(width == lineWidth ? Color.blue.opacity(0.3) : Color.clear)
                    )
                }
            }
        }
        .padding(12)
        .frame(minWidth: 200, minHeight: 80) // Enforce minimum size
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red, lineWidth: 3) // Very visible border
        )
        .cornerRadius(8)
        .shadow(color: .white.opacity(0.5), radius: 5)
    }
    
    // MARK: - Tool Actions
    
    private func handleToolTap(_ tool: DrawingTool) {
        // When any tool is tapped, we're no longer in the "no tool selected" state
        noToolSelected = false
        
        // Enable canvas interactions for all canvases 
        CanvasManager.shared.enableCanvasInteractions()
        
        switch tool.type {
        case .pen:
            selectedTool = .pen
            applyToolWithCanvasManager()
            toggleWidthOptions(for: tool.type)
            showColorPicker = false
        case .pencil:
            selectedTool = .pencil
            applyToolWithCanvasManager()
            toggleWidthOptions(for: tool.type)
            showColorPicker = false
        case .marker:
            selectedTool = .marker
            applyToolWithCanvasManager()
            toggleWidthOptions(for: tool.type)
            showColorPicker = false
        case .eraser:
            isEraserSelected = true
            applyEraserToAllCanvases()
            toggleWidthOptions(for: tool.type)
            showColorPicker = false
        case .colorPicker:
            // Legacy color picker - could be removed since we now have integrated color options
            showColorPicker.toggle()
            toolShowingWidthOptions = nil
        case .selection:
            isEraserSelected = false
            applySelectionToolToAllCanvases()
            toolShowingWidthOptions = nil
        case .aiTool:
            showAIActionSheet()
            toolShowingWidthOptions = nil
        case .undo:
            undoOnAllCanvases()
            toolShowingWidthOptions = nil
        case .redo:
            redoOnAllCanvases()
            toolShowingWidthOptions = nil
        case .widthPicker:
            showWidthPicker.toggle()
            toolShowingWidthOptions = nil
        }
    }
    
    /// Apply the current tool using CanvasManager
    private func applyToolWithCanvasManager() {
        guard let coordinator = coordinator else { return }
        
        // Convert the SwiftUI Color to UIColor
        let uiColor = UIColor(selectedColor)
        
        // Use PKInkingTool.convertColor to handle dark/light mode properly
        // First get the current interface style
        let interfaceStyle = coordinator.canvasViews.first?.value.traitCollection.userInterfaceStyle ?? .light
        
        // Then convert the color appropriately for the current interface style
        let correctColor: UIColor
        if #available(iOS 14.0, *) {
            // Use direct method if available
            correctColor = PKInkingTool.convertColor(uiColor, from: .light, to: interfaceStyle)
        } else {
            // Fallback for older iOS versions - extract components properly
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            correctColor = interfaceStyle == .dark ? 
                UIColor(red: 1-r, green: 1-g, blue: 1-b, alpha: a) :
                uiColor
        }
        
        // Apply the tool to all canvases
        coordinator.setCustomTool(
            type: selectedTool,
            color: correctColor,
            width: lineWidth
        )
        
        // Save current tool settings for next session
        saveLastUsedToolSettings()
        
        print("📌 Applied \(selectedTool) tool with color \(correctColor.description) and width \(lineWidth)")
    }
    
    // Save the last used tool settings for next session
    private func saveLastUsedToolSettings() {
        // Save tool type
        UserDefaults.standard.set(selectedTool.rawValue, forKey: "lastToolType")
        
        // Save color (using our robust RGBA storage)
        let colorData = RGBAColor(from: selectedColor)
        if let encoded = try? JSONEncoder().encode(colorData) {
            UserDefaults.standard.set(encoded, forKey: "lastSelectedColor")
        }
        
        // Save line width
        UserDefaults.standard.set(lineWidth, forKey: "lastLineWidth")
    }
    
    private func applyEraserToAllCanvases() {
        guard let coordinator = coordinator else { return }
        
        // Get the appropriate eraser
        let eraserTool = PKEraserTool(PKEraserTool.EraserType.vector)
        
        // Apply to each canvas view
        for (_, canvasView) in coordinator.canvasViews {
            canvasView.tool = eraserTool
        }
        
        print("🧹 Applied eraser tool to \(coordinator.canvasViews.count) canvases")
    }
    
    private func applySelectionToolToAllCanvases() {
        guard let coordinator = coordinator else { return }
        
        // For now, if available, use PKLassoTool
        if #available(iOS 14.0, *) {
            let selectionTool = PKLassoTool()
            
            for (_, canvasView) in coordinator.canvasViews {
                canvasView.tool = selectionTool
            }
            
            print("🎯 Applied selection tool to \(coordinator.canvasViews.count) canvases")
        } else {
            // Fallback for older iOS versions - just use a distinctive pen color
            let fallbackTool = PKInkingTool(.pen, color: UIColor.orange, width: 2)
            
            for (_, canvasView) in coordinator.canvasViews {
                canvasView.tool = fallbackTool
            }
            
            print("⚠️ Selection tool not available, using fallback")
        }
    }
    
    private func showAIActionSheet() {
        print("🧠 AI Tool tapped - functionality will be implemented later")
        // This would normally show options like "Recognize Text", "Find Similar Notes", etc.
        
        // For now, just show a visual indicator
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func undoOnAllCanvases() {
        guard let coordinator = coordinator else { return }
        
        for (_, canvasView) in coordinator.canvasViews {
            if let undoManager = canvasView.undoManager, undoManager.canUndo {
                undoManager.undo()
                print("↩️ Undo performed on canvas")
            }
        }
    }
    
    private func redoOnAllCanvases() {
        guard let coordinator = coordinator else { return }
        
        for (_, canvasView) in coordinator.canvasViews {
            if let undoManager = canvasView.undoManager, undoManager.canRedo {
                undoManager.redo()
                print("↪️ Redo performed on canvas")
            }
        }
    }
    
    // MARK: - Customization Mode
    
    private func startLongPressTimer() {
        cancelLongPressTimer() // Cancel any existing timer
        
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            enterCustomizationMode()
        }
    }
    
    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    private func enterCustomizationMode() {
        withAnimation {
            isCustomizing = true
            wiggleAmount = 3.0 
        }
        
        // Start a timer to handle the wiggle animation properly
        wiggleTimer?.invalidate()
        wiggleTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                // Toggle between positive and negative values
                self.wiggleAmount = self.wiggleAmount > 0 ? -3.0 : 3.0
            }
        }
    }
    
    private func exitCustomizationMode() {
        // Stop the wiggle timer
        wiggleTimer?.invalidate()
        wiggleTimer = nil
        
        withAnimation {
            isCustomizing = false
            wiggleAmount = 0.0 // Stop wiggling
        }
        
        // Save the tool order
        saveToolConfiguration()
    }
    
    // MARK: - Preferences Storage
    
    private func loadSavedPreferences() {
        // Load toolbar position
        if let savedPositionString = UserDefaults.standard.string(forKey: "toolbarPosition"),
           let savedPosition = ToolbarPosition(rawValue: savedPositionString) {
            self.toolbarPosition = savedPosition
        }
        
        // Load tool configuration
        if let savedTools = UserDefaults.standard.data(forKey: "toolbarTools"),
           let decodedTools = try? JSONDecoder().decode([DrawingTool].self, from: savedTools) {
            // Check if the saved tools contain our new tools
            let hasSelectionTool = decodedTools.contains(where: { $0.type == .selection })
            let hasAITool = decodedTools.contains(where: { $0.type == .aiTool })
            
            // If both are present, use the saved tools
            if hasSelectionTool && hasAITool {
                self.tools = decodedTools
            } else {
                // Otherwise, ensure our default array includes the new tools
                self.tools = [
                    DrawingTool(type: .pen),
                    DrawingTool(type: .pencil),
                    DrawingTool(type: .marker),
                    DrawingTool(type: .eraser),
                    DrawingTool(type: .selection),  // Ensure selection tool is included
                    DrawingTool(type: .aiTool),     // Ensure AI tool is included
                    DrawingTool(type: .undo),
                    DrawingTool(type: .redo)
                ]
                
                // Save the updated tool configuration
                saveToolConfiguration()
            }
        } else {
            // If no saved tools, make sure we use the default with both new tools
            print("No saved tools found, using defaults with selection and AI tools")
        }
    }
    
    private func saveToolbarPosition() {
        UserDefaults.standard.set(toolbarPosition.rawValue, forKey: "toolbarPosition")
    }
    
    private func saveToolConfiguration() {
        if let encodedTools = try? JSONEncoder().encode(tools) {
            UserDefaults.standard.set(encodedTools, forKey: "toolbarTools")
        }
    }
    
    // Add a helper function to determine the drop index
    private func getDropIndex(at location: CGPoint) -> Int? {
        // In a production app, you'd need more sophisticated logic here
        // This is just a simplified approach
        
        // Calculate the position relative to the toolbar
        let toolbarWidth = CGFloat(tools.count * 40) // Estimate width of each tool
        let relativePosition = location.x / toolbarWidth
        
        // Calculate the index based on position
        let index = Int(relativePosition * CGFloat(tools.count))
        
        // Bound the index to the array limits
        return max(0, min(tools.count - 1, index))
    }
    
    // Add this method to handle tool reordering
    private func moveToolInArray(from source: Int, to destination: Int) {
        guard source != destination && tools.indices.contains(source) && tools.indices.contains(destination) else {
            return
        }
        
        withAnimation(.spring()) {
            let sourceItem = tools[source]
            tools.remove(at: source)
            tools.insert(sourceItem, at: destination)
        }
        
        // Save the updated configuration
        saveToolConfiguration()
    }
    
    // 1. First, let's update the horizontal width picker to include colors
    private func horizontalWidthPicker(for toolType: DrawingTool.ToolType) -> some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.gray.opacity(0.5))
                .padding(.vertical, 4)
            
            // Width options with Add button
            HStack(spacing: 16) {
                ForEach(lineWidths, id: \.self) { width in
                    Button {
                        self.lineWidth = width
                        applyToolWithCanvasManager()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary, lineWidth: 1)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .fill(renderAccurateColor(selectedColor))
                                .frame(width: width * 2.5, height: width * 2.5)
                            
                            if width == lineWidth {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                }
                
                // Add custom width button
                Button {
                    showCustomWidthInput.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary, lineWidth: 1)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Custom width input
            if showCustomWidthInput {
                VStack(spacing: 4) {
                    Text("Custom Width: \(Int(tempCustomWidth))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Slider(value: $tempCustomWidth, in: 1...20, step: 1)
                            .frame(width: 120)
                        
                        Button {
                            if !lineWidths.contains(tempCustomWidth) {
                                // Add the custom width to the array
                                lineWidths.append(tempCustomWidth)
                                lineWidth = tempCustomWidth
                                applyToolWithCanvasManager()
                                
                                // Save to UserDefaults
                                saveCustomSettings()
                            }
                            showCustomWidthInput = false
                        } label: {
                            Text("Add")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity)
            }
            
            Divider()
                .background(Color.gray.opacity(0.5))
                .padding(.vertical, 4)
            
            // Color options with Add button
            HStack(spacing: 12) {
                ForEach(colors.indices, id: \.self) { index in
                    Button {
                        // First click selects the color
                        if selectedColor != colors[index] {
                            self.selectedColor = colors[index]
                            applyToolWithCanvasManager()
                        } else {
                            // Second click on already selected color opens picker to change it
                            showColorPickerForIndex = index
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(renderAccurateColor(colors[index]))
                                .frame(width: 30, height: 30)
                            
                            if colors[index] == selectedColor {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 34, height: 34)
                            }
                        }
                    }
                }
            }
            
            // If a color is being edited, show the color picker overlay
            if let editingIndex = showColorPickerForIndex {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Change Color")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ColorPicker("", selection: $tempCustomColor)
                        .labelsHidden()
                        .frame(width: 120)
                    
                    HStack {
                        Button {
                            // Replace color at this index
                            colors[editingIndex] = tempCustomColor
                            selectedColor = tempCustomColor
                            applyToolWithCanvasManager()
                            
                            // Save to UserDefaults
                            saveCustomSettings()
                            showColorPickerForIndex = nil
                        } label: {
                            Text("Update")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                        
                        Button {
                            showColorPickerForIndex = nil
                        } label: {
                            Text("Cancel")
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .frame(height: showCustomWidthInput || showColorPickerForIndex != nil ? 180 : 120)
        .animation(.spring(), value: showCustomWidthInput)
        .animation(.spring(), value: showColorPickerForIndex)
    }
    
    // 2. Update the vertical/side width picker as well
    private func sideWidthPicker(for toolType: DrawingTool.ToolType) -> some View {
        HStack(spacing: 4) {
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 1)
                .padding(.horizontal, 4)
            
            // Options in a vertical stack
            VStack(spacing: 16) {
                // Width section
                VStack(spacing: 12) {
                    Text("Width")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(lineWidths, id: \.self) { width in
                        Button {
                            self.lineWidth = width
                            applyToolWithCanvasManager()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary, lineWidth: 1)
                                    .frame(width: 32, height: 32)
                                
                                Circle()
                                    .fill(renderAccurateColor(selectedColor))
                                    .frame(width: width * 2.5, height: width * 2.5)
                                
                                if width == lineWidth {
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                        .frame(width: 36, height: 36)
                                }
                            }
                        }
                    }
                    
                    // Add custom width button
                    Button {
                        showCustomWidthInput.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary, lineWidth: 1)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Custom width input
                if showCustomWidthInput {
                    VStack(spacing: 4) {
                        Text("Width: \(Int(tempCustomWidth))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $tempCustomWidth, in: 1...20, step: 1)
                            .frame(width: 70)
                        
                        Button {
                            if !lineWidths.contains(tempCustomWidth) {
                                lineWidths.append(tempCustomWidth)
                                lineWidth = tempCustomWidth
                                applyToolWithCanvasManager()
                                saveCustomSettings()
                            }
                            showCustomWidthInput = false
                        } label: {
                            Text("Add")
                                .foregroundColor(.blue)
                                .font(.caption2)
                        }
                    }
                    .padding(.vertical, 4)
                    .transition(.opacity)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.5))
                    .padding(.vertical, 4)
                
                // Color section
                VStack(spacing: 8) {
                    Text("Color")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Maintain the grid layout for the 6 colors  
                    ForEach(0..<((colors.count + 1) / 2), id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<2) { col in
                                let index = row * 2 + col
                                if index < colors.count {
                                    Button {
                                        // First click selects the color
                                        if selectedColor != colors[index] {
                                            self.selectedColor = colors[index]
                                            applyToolWithCanvasManager()
                                        } else {
                                            // Second click on already selected color opens picker to change it
                                            showColorPickerForIndex = index
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(renderAccurateColor(colors[index]))
                                                .frame(width: 24, height: 24)
                                            
                                            if colors[index] == selectedColor {
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                                    .frame(width: 28, height: 28)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Add this color picker when editing a color
                    if let editingIndex = showColorPickerForIndex {
                        VStack(alignment: .leading, spacing: 4) {
                            ColorPicker("", selection: $tempCustomColor)
                                .labelsHidden()
                                .frame(width: 70)
                            
                            HStack {
                                Button {
                                    // Replace color at this index
                                    colors[editingIndex] = tempCustomColor
                                    selectedColor = tempCustomColor
                                    applyToolWithCanvasManager()
                                    
                                    // Save to UserDefaults
                                    saveCustomSettings()
                                    showColorPickerForIndex = nil
                                } label: {
                                    Text("✓")
                                        .foregroundColor(.blue)
                                        .font(.caption2)
                                }
                                
                                Button {
                                    showColorPickerForIndex = nil
                                } label: {
                                    Text("✕")
                                        .foregroundColor(.red)
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .transition(.opacity)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .frame(width: showCustomWidthInput || showCustomColorPicker ? 120 : 90)
        .animation(.spring(), value: showCustomWidthInput)
        .animation(.spring(), value: showCustomColorPicker)
    }
    
    // MARK: - Tool Management with CanvasManager
    
    /// Sync local tool state with CanvasManager
    private func syncWithCanvasManager() {
        // Get current tool from CanvasManager
        let canvasManager = CanvasManager.shared
        
        // Update bindings to match CanvasManager state
        self.selectedTool = canvasManager.currentTool
        self.selectedColor = Color(canvasManager.currentColor)
        self.lineWidth = canvasManager.currentLineWidth
    }
    
    /// Handle tool change events from EventBus
    private func handleToolChangeEvent(_ event: ToolEvents.ToolChanged) {
        // Update bindings to match notification values
        DispatchQueue.main.async {
            self.selectedTool = event.tool
            self.selectedColor = Color(event.color)
            self.lineWidth = event.width
        }
    }
    
    // MARK: - Helper Functions
    
    // 6. Add this preference key to track view positions
    struct ViewPositionKey: PreferenceKey {
        static var defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
        }
    }
    
    // Helper to check if a color already exists
    private func colorExists(_ color: Color) -> Bool {
        // Convert the color to RGB components for comparison
        let newColorUI = UIColor(color)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        newColorUI.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        
        for existingColor in colors {
            let existingUI = UIColor(existingColor)
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            existingUI.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            // Compare with a small tolerance for floating point differences
            if abs(r1-r2) < 0.01 && abs(g1-g2) < 0.01 && abs(b1-b2) < 0.01 {
                return true
            }
        }
        return false
    }
    
    // Save custom settings to UserDefaults
    private func saveCustomSettings() {
        // Convert [Color] to [RGBAColor]
        let colorData = colors.map { RGBAColor(from: $0) }
        if let encoded = try? JSONEncoder().encode(colorData) {
            UserDefaults.standard.set(encoded, forKey: "customColors")
        }
        
        UserDefaults.standard.set(lineWidths, forKey: "customLineWidths")
    }
    
    // Load custom settings from UserDefaults
    private func loadCustomSettings() {
        // Load last used tool type
        if let toolRawValue = UserDefaults.standard.string(forKey: "lastToolType"),
           let toolType = PKInkingTool.InkType(rawValue: toolRawValue) {
            selectedTool = toolType
        } else {
            // Default to pen if no saved tool
            selectedTool = .pen
        }
        
        // Load last used color
        if let colorData = UserDefaults.standard.data(forKey: "lastSelectedColor"),
           let decoded = try? JSONDecoder().decode(RGBAColor.self, from: colorData) {
            selectedColor = decoded.swiftUIColor
        }
        
        // Load last used line width
        if let width = UserDefaults.standard.object(forKey: "lastLineWidth") as? CGFloat {
            lineWidth = width
        }
        
        // Load line widths
        if let savedWidths = UserDefaults.standard.array(forKey: "customLineWidths") as? [CGFloat], !savedWidths.isEmpty {
            lineWidths = savedWidths
        }
        
        // Load colors from RGBA encoding
        if let data = UserDefaults.standard.data(forKey: "customColors"),
           let decoded = try? JSONDecoder().decode([RGBAColor].self, from: data), !decoded.isEmpty {
            colors = decoded.map { $0.swiftUIColor }
        }
    }
    
    // Add this helper function to ensure colors are rendered accurately
    private func renderAccurateColor(_ color: Color) -> Color {
        // Get the tool-specific rendering of the color
        return getAccurateDrawingColor(
            for: isEraserSelected ? .eraser : 
                 selectedTool == .pen ? .pen :
                 selectedTool == .pencil ? .pencil : .marker,
            baseColor: color
        )
    }
    
    private func getAccurateDrawingColor(for toolType: DrawingTool.ToolType, baseColor: Color) -> Color {
        // First, capture the color components in a device-independent way
        let components = baseColor.cgColor?.components ?? [0, 0, 0, 1]
        
        // Create a new color using explicit sRGB color space for consistency
        let uiColor = UIColor(
            displayP3Red: components[0],
            green: components[1],
            blue: components[2],
            alpha: components[3]
        )
        
        // Handle tool-specific adjustments
        switch toolType {
        case .pen:
            // Pens typically render at full opacity
            return Color(uiColor)
        case .marker:
            // Markers are often semi-transparent
            // Use withAlphaComponent only on the final output
            return Color(uiColor.withAlphaComponent(0.7))
        case .pencil:
            // Pencils might have a slight texture or reduced opacity
            return Color(uiColor.withAlphaComponent(0.9))
        case .eraser:
            // Erasers don't need color adjustments
            return baseColor
        default:
            return baseColor
        }
    }
    
    // Replace the previous clearToolSelection method with this one
    private func clearToolSelection() {
        // Clear visual selection state
        noToolSelected = true
        isEraserSelected = false
        
        // Use the CanvasManager to clear tools from all canvases
        CanvasManager.shared.clearToolSelection()
        
        print("🖋️ CustomToolbar: Cleared tool selection")
    }
}

// OPTIONAL: A more robust approach is to store colors by RGBA instead
// instead of `color.description`. For instance:
struct RGBAColor: Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
    var useDisplayP3: Bool = false
    
    init(from color: Color) {
        // Use temporary local vars
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        
        let uiColor = UIColor(color)
        
        // Try to get components from the color
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            // Successfully got RGB components
            self.useDisplayP3 = false
        } else {
            // If standard RGB conversion fails, try with DisplayP3
            // First convert to CGColor which has components we can access
            if let components = uiColor.cgColor.components, uiColor.cgColor.numberOfComponents >= 4 {
                r = components[0]
                g = components[1]
                b = components[2]
                a = components[3]
                self.useDisplayP3 = true
            } else if let components = uiColor.cgColor.components, uiColor.cgColor.numberOfComponents >= 2 {
                // Handle grayscale + alpha color space
                r = components[0]
                g = components[0]
                b = components[0]
                a = components[1]
                self.useDisplayP3 = false
            }
        }
        
        self.red = r
        self.green = g 
        self.blue = b
        self.alpha = a
    }
    
    var swiftUIColor: Color {
        if useDisplayP3 {
            return Color(UIColor(displayP3Red: red, green: green, blue: blue, alpha: alpha))
        } else {
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        }
    }
} 
