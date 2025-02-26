//
//  SimplifiedNoteDetailView.swift
//  SmartNotes
//
//  Created on 2/25/25.
//

import SwiftUI
import PencilKit

struct SimplifiedNoteDetailView: View {
    @Binding var note: Note
    @State private var localTitle: String
    @State private var isCanvasEnabled = false
    @Environment(\.presentationMode) private var presentationMode
    
    init(note: Binding<Note>) {
        self._note = note
        self._localTitle = State(initialValue: note.wrappedValue.title)
        print("🔎 SimplifiedNoteDetailView initializing for note: \(note.wrappedValue.title)")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Debug info
            Text("Debug View")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
            
            // Title area
            TextField("Note Title", text: $localTitle)
                .font(.title)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: localTitle) { newValue in
                    note.title = newValue
                }
                .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            // Toggle for canvas
            Toggle("Enable Canvas (might freeze)", isOn: $isCanvasEnabled)
                .padding()
                .foregroundColor(.red)
            
            if isCanvasEnabled {
                // Only show the canvas if explicitly enabled
                CanvasContainer(note: $note)
            } else {
                // Placeholder content
                VStack {
                    Text("Canvas disabled for debugging")
                        .font(.headline)
                        .padding()
                    
                    Text("Enable the toggle above to test canvas initialization")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.1))
            }
        }
        .navigationTitle(localTitle.isEmpty ? "Untitled" : localTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    saveChanges()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            print("🔎 SimplifiedNoteDetailView appeared")
        }
        .onDisappear {
            print("🔎 SimplifiedNoteDetailView disappeared")
            saveChanges()
        }
    }
    
    private func saveChanges() {
        print("🔎 Saving changes to note")
        note.title = localTitle
    }
}

// Separate container for the canvas to isolate potential issues
struct CanvasContainer: View {
    @Binding var note: Note
    @State private var pkDrawing = PKDrawing()
    
    var body: some View {
        VStack {
            Text("Canvas Container")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.top, 4)
            
            // Use a simpler canvas view for testing
            SimpleCanvasView(drawing: $pkDrawing)
                .onAppear {
                    print("🔎 Loading drawing data: \(note.drawingData.count) bytes")
                    if !note.drawingData.isEmpty {
                        pkDrawing = PKDrawing.fromData(note.drawingData)
                    } else {
                        pkDrawing = PKDrawing()
                    }
                }
                .onChange(of: pkDrawing) { newValue in
                    print("🔎 Drawing changed, saving: \(newValue.dataRepresentation().count) bytes")
                    note.drawingData = newValue.dataRepresentation()
                }
        }
    }
}

// A simplified canvas view without paging for testing
struct SimpleCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    
    func makeUIView(context: Context) -> PKCanvasView {
        print("🔎 SimpleCanvasView - makeUIView called")
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.backgroundColor = .white
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 2)
        canvas.delegate = context.coordinator
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        print("🔎 SimpleCanvasView - updateUIView called")
        uiView.drawing = drawing
    }
    
    func makeCoordinator() -> Coordinator {
        print("🔎 SimpleCanvasView - makeCoordinator called")
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: SimpleCanvasView
        
        init(_ parent: SimpleCanvasView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            print("🔎 SimpleCanvasView - drawing changed")
            parent.drawing = canvasView.drawing
        }
    }
}
