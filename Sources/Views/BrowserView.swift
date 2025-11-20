import SwiftUI
import WebKit

struct BrowserView: View {
    @EnvironmentObject var browserState: BrowserState
    @State private var urlString: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack(spacing: 8) {
                Button(action: { browserState.goBack() }) {
                    Image(systemName: "chevron.left")
                        .disabled(!browserState.canGoBack)
                }
                .buttonStyle(.borderless)
                .disabled(!browserState.canGoBack)
                
                Button(action: { browserState.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!browserState.canGoForward)
                
                Button(action: { browserState.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                
                TextField("Enter URL", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        browserState.navigate(to: urlString)
                    }
                    .onChange(of: browserState.currentURL) { newURL in
                        if let url = newURL {
                            urlString = url.absoluteString
                        }
                    }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Web View
            BrowserWebViewRepresentable()
                .environmentObject(browserState)
        }
    }
}

struct BrowserWebViewRepresentable: NSViewRepresentable {
    @EnvironmentObject var browserState: BrowserState
    
    func makeNSView(context: Context) -> BrowserWebView {
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
    
    override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
        let config = WKWebViewConfiguration()
        // JavaScript is enabled by default in WKWebView
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        super.init(frame: frame, configuration: config)
        
        // Add message handler for METAL bridge after super.init
        config.userContentController.add(self, name: "metalBridge")
        self.navigationDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setBrowserState(_ state: BrowserState) {
        self.browserState = state
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
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
        load(URLRequest(url: url))
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        browserState?.updateLoadingState(true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        browserState?.updateLoadingState(false)
        browserState?.updateNavigationState(
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )
        webView.evaluateJavaScript("document.title") { result, error in
            if let title = result as? String {
                self.browserState?.updateTitle(title)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        browserState?.updateLoadingState(false)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

