//
//  TemplateCanvasView.swift
//  SmartNotes
//
//  Created on 2/26/25.
//

import SwiftUI
import PencilKit

struct TemplateCanvasView: View {
    @Binding var drawing: PKDrawing
    @State private var showingTemplateSettings = false
    @State private var template: CanvasTemplate = .none
    
    // Add storage of template with note
    private let templateKey = "note.template"
    
    var body: some View {
        ZStack {
            // The main canvas view - pass the template binding
            PagedCanvasView(drawing: $drawing, template: $template)
        }
        .sheet(isPresented: $showingTemplateSettings) {
            TemplateSettingsView(template: $template)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTemplateSettings"))) { _ in
            showingTemplateSettings = true
        }
        .onAppear {
            // Try to load saved template settings from UserDefaults
            if let savedData = UserDefaults.standard.data(forKey: templateKey) {
                do {
                    let savedTemplate = try JSONDecoder().decode(CanvasTemplate.self, from: savedData)
                    template = savedTemplate
                    print("📝 Loaded template settings: \(savedTemplate.type.rawValue)")
                } catch {
                    print("📝 Error loading template settings: \(error)")
                }
            }
        }
        .onChange(of: template) { newTemplate in
            // Save template settings when they change
            do {
                let data = try JSONEncoder().encode(newTemplate)
                UserDefaults.standard.set(data, forKey: templateKey)
                print("📝 Saved template settings: \(newTemplate.type.rawValue)")
            } catch {
                print("📝 Error saving template settings: \(error)")
            }
        }
    }
}
