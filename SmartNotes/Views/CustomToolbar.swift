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
        DrawingTool(type: .colorPicker),
        DrawingTool(type: .eraser),
        DrawingTool(type: .selection),
        DrawingTool(type: .aiTool),
        DrawingTool(type: .undo),
        DrawingTool(type: .redo)
    ]
    
    // Available colors
    let colors: [Color] = [.black, .blue, .red, .green, .orange, .purple]
    
    // Available line widths
    let lineWidths: [CGFloat] = [1, 2, 4, 6, 10]
    
    // Add these state variables to CustomToolbar
    @State private var draggedTool: DrawingTool?
    @State private var draggedToolLocation: CGPoint?
    
    // New animation timer
    @State private var wiggleTimer: Timer?
    
    // Add a state to track which tool is showing size options
    @State private var toolShowingWidthOptions: DrawingTool.ToolType?
    
    // 1. First, add a state to track the position of the selected tool
    @State private var activeToolFrame: CGRect = .zero
    
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
            // Reset toolbar preferences (remove this after testing)
            UserDefaults.standard.removeObject(forKey: "toolbarTools")
            
            loadSavedPreferences()
            // Initial setup of tools
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                applyToolToAllCanvases()
            }
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
                            .frame(width: 70) // Constrain width
                    }
                    
                    // Main vertical toolbar
                    verticalToolbar()
                    
                    // For left toolbar, show picker on the right
                    if toolbarPosition == .left, let toolType = toolShowingWidthOptions {
                        sideWidthPicker(for: toolType)
                            .frame(width: 70) // Constrain width
                    }
                }
                // Add a fixed width for the entire toolbar
                .frame(maxWidth: toolShowingWidthOptions != nil ? 150 : 80)
            } else {
                VStack(spacing: 0) {
                    // Extended width picker (above if bottom toolbar)
                    if let toolType = toolShowingWidthOptions, toolbarPosition == .bottom {
                        horizontalWidthPicker(for: toolType)
                            .frame(height: 60) // Constrain height
                    }
                    
                    // Main horizontal toolbar
                    horizontalToolbar()
                    
                    // Extended width picker (below if top toolbar)
                    if let toolType = toolShowingWidthOptions, toolbarPosition == .top {
                        horizontalWidthPicker(for: toolType)
                            .frame(height: 60) // Constrain height
                    }
                }
                // Add a fixed height for the entire toolbar
                .frame(maxHeight: toolShowingWidthOptions != nil ? 150 : 80)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        // Fix the layout so it doesn't expand
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
                        applyToolToAllCanvases()
                    }
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                        )
                }
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
                        applyToolToAllCanvases()
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
        switch tool.type {
        case .pen:
            selectedTool = .pen
            isEraserSelected = false
            applyToolToAllCanvases()
            toggleWidthOptions(for: tool.type)
        case .pencil:
            selectedTool = .pencil
            isEraserSelected = false
            applyToolToAllCanvases()
            toggleWidthOptions(for: tool.type)
        case .marker:
            selectedTool = .marker
            isEraserSelected = false
            applyToolToAllCanvases()
            toggleWidthOptions(for: tool.type)
        case .eraser:
            isEraserSelected = true
            applyEraserToAllCanvases()
            toggleWidthOptions(for: tool.type)
        case .colorPicker:
            showColorPicker.toggle()
            toolShowingWidthOptions = nil
        case .selection:
            isEraserSelected = false
            applySelectionToolToAllCanvases()
            toolShowingWidthOptions = nil
        case .aiTool:
            isEraserSelected = false
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
    
    // MARK: - Canvas Operations
    
    private func applyToolToAllCanvases() {
        guard let coordinator = coordinator else { return }
        
        // Create the tool with selected properties
        let tool = PKInkingTool(selectedTool, color: UIColor(selectedColor), width: lineWidth)
        
        // Apply to each canvas view
        for (_, canvasView) in coordinator.canvasViews {
            canvasView.tool = tool
        }
        
        // Log for debugging
        print("📌 Applied \(selectedTool) tool with color \(selectedColor) and width \(lineWidth) to \(coordinator.canvasViews.count) canvases")
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
                    DrawingTool(type: .colorPicker),
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
    
    // 3. Create horizontal and vertical width pickers for extending the toolbar
    private func horizontalWidthPicker(for toolType: DrawingTool.ToolType) -> some View {
        VStack(spacing: 4) {
            Divider()
                .background(Color.gray.opacity(0.5))
                .padding(.vertical, 4)
            
            HStack(spacing: 16) {
                ForEach(lineWidths, id: \.self) { width in
                    Button {
                        self.lineWidth = width
                        applyToolToAllCanvases()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary, lineWidth: 1)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .fill(selectedColor)
                                .frame(width: width * 2.5, height: width * 2.5)
                            
                            if width == lineWidth {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(height: 60) // Fixed height to prevent excessive expansion
    }
    
    private func sideWidthPicker(for toolType: DrawingTool.ToolType) -> some View {
        HStack(spacing: 4) {
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 1)
                .padding(.horizontal, 4)
            
            // Width options in a vertical stack
            VStack(spacing: 12) {
                ForEach(lineWidths, id: \.self) { width in
                    Button {
                        self.lineWidth = width
                        applyToolToAllCanvases()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary, lineWidth: 1)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .fill(selectedColor)
                                .frame(width: width * 2.5, height: width * 2.5)
                            
                            if width == lineWidth {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .frame(width: 70) // Fixed width to prevent excessive expansion
    }
    
    // 6. Add this preference key to track view positions
    struct ViewPositionKey: PreferenceKey {
        static var defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
        }
    }
} 
