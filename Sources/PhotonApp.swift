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
                        
                        // Bring window to front and remove title
                        if let window = app.windows.first {
                            window.makeKeyAndOrderFront(nil)
                            window.center()
                            window.title = "" // Remove window title
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                    // Remove title when window becomes key
                    if let window = notification.object as? NSWindow {
                        window.title = ""
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
                .environmentObject(settings)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 700, height: 800)
    }
    
    private func openSettingsWindow() {
        // Open settings window using SwiftUI's window management
        DispatchQueue.main.async {
            // Find existing settings window or let SwiftUI create it
            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // Use NSApp to request window creation via WindowGroup
                // SwiftUI will handle window creation automatically
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                // Fallback: manually trigger window opening
                if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}
