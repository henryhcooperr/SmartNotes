import SwiftUI

struct CoordinateGridToggleButton: View {
    @State private var isGridVisible = false
    
    var body: some View {
        Button(action: {
            toggleGrid()
        }) {
            VStack(spacing: 4) {
                Image(systemName: isGridVisible ? "grid.circle.fill" : "grid.circle")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Grid")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.blue)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
        }
        .keyboardShortcut("g", modifiers: [.command, .option])
        .help("Toggle 100x100 coordinate grid (⌘⌥G)")
        .onAppear {
            // Listen for notifications about grid state changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("GridStateChanged"),
                object: nil,
                queue: .main
            ) { notification in
                if let isVisible = notification.object as? Bool {
                    self.isGridVisible = isVisible
                }
            }
        }
    }
    
    private func toggleGrid() {
        isGridVisible.toggle()
        
        // Post notification to toggle grid
        NotificationCenter.default.post(
            name: NSNotification.Name("ToggleCoordinateGrid"),
            object: nil
        )
        
        // Notify about state change
        NotificationCenter.default.post(
            name: NSNotification.Name("GridStateChanged"),
            object: isGridVisible
        )
    }
}

// Helper view to position the debug button
struct DebugOverlayView: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    CoordinateGridToggleButton()
                    
                    // Additional debug information
                    Text("Page dimensions: \(Int(GlobalSettings.scaledPageSize.width))×\(Int(GlobalSettings.scaledPageSize.height))")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                    
                    Text("Spacing: \(Int(12 * ResolutionManager.shared.resolutionScaleFactor))px")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                }
                .padding(16)
            }
            Spacer()
        }
    }
}

// Extension to make it easy to add the debug overlay to any view
extension View {
    func withDebugOverlay() -> some View {
        ZStack {
            self
            DebugOverlayView()
        }
    }
}
