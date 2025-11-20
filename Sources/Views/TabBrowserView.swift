import SwiftUI
import WebKit

struct TabBrowserView: View {
    @ObservedObject var tab: BrowserTab
    
    var body: some View {
        TabBrowserWebViewRepresentable(tab: tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }
}

struct TabBrowserWebViewRepresentable: NSViewRepresentable {
    @ObservedObject var tab: BrowserTab
    
    func makeNSView(context: Context) -> BrowserWebView {
        // Only create web view if it doesn't exist
        if let existingWebView = tab.webView {
            return existingWebView
        }
        
        let webView = BrowserWebView()
        webView.setTab(tab)
        tab.setWebView(webView)
        
        // Inject METAL bridge into web view
        let metalBridge = MetalBridge()
        metalBridge.injectIntoWebView(webView)
        
        // Load initial URL if set
        if let url = tab.url {
            webView.load(url: url)
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: BrowserWebView, context: Context) {
        // Ensure the web view is still connected to the tab
        // Check if tab needs to be set (using a helper method)
        if let currentTab = nsView.getTab(), currentTab.id != tab.id {
            nsView.setTab(tab)
            tab.setWebView(nsView)
        } else if nsView.getTab() == nil {
            nsView.setTab(tab)
            tab.setWebView(nsView)
        }
    }
}

