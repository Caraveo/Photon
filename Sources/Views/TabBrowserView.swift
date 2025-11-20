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
        print("🌐 [DEBUG] Creating BrowserWebView for tab: \(tab.id)")
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
        // Updates handled by BrowserWebView
    }
}

