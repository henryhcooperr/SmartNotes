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
    
    // Currently selected tool type (ink or eraser)
    @State private var isEraserSelected = false
    
    // Available ink types
    let inkTypes: [PKInkingTool.InkType] = [.pen, .pencil, .marker]
    
    // Available colors
    let colors: [Color] = [.black, .blue, .red, .green, .orange, .purple]
    
    // Available line widths
    let lineWidths: [CGFloat] = [1, 2, 4, 6, 10]
    
    var body: some View {
        VStack(spacing: 0) {
            // Main toolbar
            HStack(spacing: 16) {
                // Drawing tools
                ForEach(inkTypes, id: \.self) { inkType in
                    Button {
                        selectedTool = inkType
                        isEraserSelected = false
                        applyToolToAllCanvases()
                    } label: {
                        Image(systemName: iconForInkType(inkType))
                            .font(.system(size: 20))
                            .foregroundColor(selectedTool == inkType && !isEraserSelected ? selectedColor : .gray)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(selectedTool == inkType && !isEraserSelected ? Color.gray.opacity(0.2) : Color.clear)
                            )
                    }
                }
                
                Divider()
                    .frame(height: 24)
                
                // Color selector
                Button {
                    showColorPicker.toggle()
                    showWidthPicker = false
                } label: {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                
                // Line width selector
                Button {
                    showWidthPicker.toggle()
                    showColorPicker = false
                } label: {
                    Image(systemName: "lineweight")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Eraser
                Button {
                    isEraserSelected = true
                    applyEraserToAllCanvases()
                } label: {
                    Image(systemName: "eraser")
                        .font(.system(size: 20))
                        .foregroundColor(isEraserSelected ? .red : .gray)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(isEraserSelected ? Color.gray.opacity(0.2) : Color.clear)
                        )
                }
                
                // Undo
                Button {
                    undoOnAllCanvases()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .padding(8)
                }
                
                // Redo
                Button {
                    redoOnAllCanvases()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            .padding(.horizontal)
            
            // Color picker panel (conditionally shown)
            if showColorPicker {
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
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Line width picker panel (conditionally shown)
            if showWidthPicker {
                HStack(spacing: 16) {
                    ForEach(lineWidths, id: \.self) { width in
                        Button {
                            lineWidth = width
                            if !isEraserSelected {
                                applyToolToAllCanvases()
                            } else {
                                applyEraserToAllCanvases()
                            }
                        } label: {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: width * 3, height: width * 3)
                                .overlay(
                                    Circle()
                                        .stroke(lineWidth == width ? Color.primary : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showColorPicker)
        .animation(.easeInOut(duration: 0.2), value: showWidthPicker)
        .onAppear {
            // Initial setup of tools
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                applyToolToAllCanvases()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Convert ink type to icon name
    private func iconForInkType(_ inkType: PKInkingTool.InkType) -> String {
        switch inkType {
        case .pen:
            return "pencil.tip"
        case .pencil:
            return "pencil"
        case .marker:
            return "highlighter"
        default:
            return "pencil"
        }
    }
    
    // Apply the selected tool to all canvas views
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
    
    // Apply eraser to all canvas views
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
    
    // Undo on all canvases
    private func undoOnAllCanvases() {
        guard let coordinator = coordinator else { return }
        
        for (_, canvasView) in coordinator.canvasViews {
            if let undoManager = canvasView.undoManager, undoManager.canUndo {
                undoManager.undo()
                print("↩️ Undo performed on canvas")
            }
        }
    }
    
    // Redo on all canvases
    private func redoOnAllCanvases() {
        guard let coordinator = coordinator else { return }
        
        for (_, canvasView) in coordinator.canvasViews {
            if let undoManager = canvasView.undoManager, undoManager.canRedo {
                undoManager.redo()
                print("↪️ Redo performed on canvas")
            }
        }
    }
} 