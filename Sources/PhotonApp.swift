import SwiftUI
import AppKit

// Window delegate to handle Settings window lifecycle
class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Cancel any running tasks when window closes
        // The window delegate is called before the window is deallocated
        // This gives us a chance to clean up
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow window to close normally, but use orderOut to avoid animation issues
        // Return true to allow close, but we'll handle it with orderOut in the button action
        return true
    }
}

@main
struct PhotonApp: App {
    @StateObject private var browserState = BrowserState()
    @StateObject private var settings = AISettings()
    @StateObject private var aiService: LocalAIService
    
    init() {
        // Create settings first
        let settings = AISettings()
        // Create aiService with settings
        let aiService = LocalAIService(settings: settings)
        // Initialize state objects
        _settings = StateObject(wrappedValue: settings)
        _aiService = StateObject(wrappedValue: aiService)
    }
    
    var body: some Scene {
        WindowGroup {
            MainBrowserView()
                .environmentObject(browserState)
                .environmentObject(aiService)
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
            SettingsView(settings: settings, aiService: aiService)
                .environmentObject(settings)
                .environmentObject(aiService)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 700, height: 800)
    }
    
    private func openSettingsWindow() {
        // Open settings window using SwiftUI's window management
        DispatchQueue.main.async {
            // First, try to find existing settings window
            if let existingWindow = NSApplication.shared.windows.first(where: { 
                $0.identifier?.rawValue == "settings" || $0.title == "Settings"
            }) {
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // Create new window using NSWindow
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 700, height: 800),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "Settings"
                window.identifier = NSUserInterfaceItemIdentifier("settings")
                window.center()
                
                // Set delegate to handle window closing
                window.delegate = SettingsWindowDelegate()
                
                // Create hosting view
                let hostingView = NSHostingView(
                    rootView: SettingsView(settings: settings, aiService: aiService)
                        .environmentObject(settings)
                        .environmentObject(aiService)
                )
                window.contentView = hostingView
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
