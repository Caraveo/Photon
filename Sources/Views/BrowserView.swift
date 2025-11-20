import SwiftUI
import WebKit

// Simplified - just the web view representable for the unified view
struct BrowserWebViewRepresentable: NSViewRepresentable {
    @EnvironmentObject var browserState: BrowserState
    
    func makeNSView(context: Context) -> BrowserWebView {
        print("🌐 [DEBUG] Creating BrowserWebView")
        let webView = BrowserWebView()
        webView.setBrowserState(browserState)
        browserState.setWebView(webView)
        
        // Inject METAL bridge into web view
        let metalBridge = MetalBridge()
        metalBridge.injectIntoWebView(webView)
        
        return webView
    }
    
    func updateNSView(_ nsView: BrowserWebView, context: Context) {
        // Updates handled by BrowserWebView
    }
}

class BrowserWebView: WKWebView, WKNavigationDelegate, WKScriptMessageHandler {
    private var browserState: BrowserState?
    private var tab: BrowserTab?
    
    override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        super.init(frame: frame, configuration: config)
        
        // Add message handler for METAL bridge after super.init
        config.userContentController.add(self, name: "metalBridge")
        self.navigationDelegate = self
        
        print("🌐 [DEBUG] BrowserWebView initialized")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setBrowserState(_ state: BrowserState) {
        self.browserState = state
        print("🌐 [DEBUG] BrowserState set")
    }
    
    func setTab(_ tab: BrowserTab) {
        self.tab = tab
        print("🌐 [DEBUG] Tab set: \(tab.id)")
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("🌐 [DEBUG] Received message: \(message.name)")
        if message.name == "metalBridge" {
            // Handle messages from TypeScript bridge
            if let messageBody = message.body as? [String: Any],
               let action = messageBody["action"] as? String,
               action == "sendToAI",
               let _ = messageBody["message"] as? String {
                Task {
                    // Process AI request
                    // This would be handled by the AI service
                }
            }
        }
    }
    
    func load(url: URL) {
        print("🌐 [DEBUG] Loading URL: \(url.absoluteString)")
        load(URLRequest(url: url))
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🌐 [DEBUG] Navigation started")
        browserState?.updateLoadingState(true)
        tab?.isLoading = true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("🌐 [DEBUG] Navigation finished")
        browserState?.updateLoadingState(false)
        tab?.isLoading = false
        tab?.canGoBack = webView.canGoBack
        tab?.canGoForward = webView.canGoForward
        tab?.url = webView.url
        
        browserState?.updateNavigationState(
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )
        webView.evaluateJavaScript("document.title") { result, error in
            if let title = result as? String {
                print("🌐 [DEBUG] Page title: \(title)")
                self.browserState?.updateTitle(title)
                self.tab?.title = title.isEmpty ? "New Tab" : title
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ [DEBUG] Navigation failed: \(error.localizedDescription)")
        browserState?.updateLoadingState(false)
        tab?.isLoading = false
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}
