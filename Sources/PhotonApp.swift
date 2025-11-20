import SwiftUI
import AppKit

@main
struct PhotonApp: App {
    @StateObject private var browserState = BrowserState()
    @StateObject private var settings = AISettings()
    
    private var aiService: LocalAIService {
        LocalAIService(settings: settings)
    }
    
    var body: some Scene {
        WindowGroup {
            MainBrowserView()
                .environmentObject(browserState)
                .environmentObject(LocalAIService(settings: settings))
                .environmentObject(settings)
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
            
            // Add keyboard shortcuts
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    // This will be handled by TabBarView
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            
            // Add Settings menu item
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        // Settings window
        WindowGroup("Settings", id: "settings") {
            SettingsView(settings: settings, aiService: LocalAIService(settings: settings))
        }
        .windowStyle(.automatic)
        .defaultSize(width: 600, height: 700)
    }
    
    private func openSettingsWindow() {
        // Open settings window using NSApplication
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                // Create new settings window
                let settingsWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )
                settingsWindow.identifier = NSUserInterfaceItemIdentifier("settings")
                settingsWindow.title = "Settings"
                settingsWindow.contentView = NSHostingView(rootView: SettingsView(settings: settings, aiService: LocalAIService(settings: settings)))
                settingsWindow.center()
                settingsWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
}
