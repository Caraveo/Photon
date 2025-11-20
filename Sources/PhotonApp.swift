import SwiftUI

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
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1400, height: 900)
    }
}

