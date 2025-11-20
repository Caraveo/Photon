import SwiftUI
import AppKit

@main
struct PhotonApp: App {
    @StateObject private var browserState = BrowserState()
    @StateObject private var aiService = LocalAIService()
    
    init() {
        // Ensure app runs as GUI application
        NSApp.setActivationPolicy(.regular)
    }
    
    var body: some Scene {
        WindowGroup {
            MainBrowserView()
                .environmentObject(browserState)
                .environmentObject(aiService)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    // Bring window to front when it appears
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApplication.shared.windows.first {
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

