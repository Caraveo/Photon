import SwiftUI

struct MainBrowserView: View {
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var aiService: LocalAIService
    
    var body: some View {
        HSplitView {
            // Left side - Browser
            BrowserView()
                .frame(minWidth: 400)
            
            // Middle - AI Interaction Bar
            AIConduitBar()
                .frame(width: 300)
            
            // Right side - Browser (optional, can be removed if not needed)
            BrowserView()
                .frame(minWidth: 400)
        }
    }
}

