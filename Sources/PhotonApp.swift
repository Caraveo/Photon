import SwiftUI
import AppKit

@main
struct PhotonApp: App {
    @StateObject private var browserState = BrowserState()
    @StateObject private var aiService = LocalAIService()
    
    var body: some Scene {
        WindowGroup {
            MainBrowserView()
                .environmentObject(browserState)
                .environmentObject(aiService)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    // Ensure app runs as GUI application and bring window to front
                    DispatchQueue.main.async {
                        let app = NSApplication.shared
                        app.setActivationPolicy(.regular)
                        app.activate(ignoringOtherApps: true)
                        
                        // Bring window to front
                        if let window = app.windows.first {
                            window.makeKeyAndOrderFront(nil)
                            window.center()
                        }
                    }
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

