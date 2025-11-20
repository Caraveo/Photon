import SwiftUI
import WebKit
import AppKit

// Simplified - just the web view representable for the unified view
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
    private var tab: BrowserTab?
    
    func getTab() -> BrowserTab? {
        return tab
    }
    
    override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        super.init(frame: frame, configuration: config)
        
        // Add message handler for METAL bridge after super.init
        config.userContentController.add(self, name: "metalBridge")
        self.navigationDelegate = self
        
        // Make scrollbars transparent
        self.setValue(false, forKey: "drawsBackground")
        
        // Configure scrollbars to be transparent using AppKit
        DispatchQueue.main.async {
            // Access the underlying scroll view
            if let scrollView = self.enclosingScrollView {
                scrollView.scrollerStyle = .overlay
                scrollView.verticalScroller?.alphaValue = 0.0
                scrollView.horizontalScroller?.alphaValue = 0.0
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setBrowserState(_ state: BrowserState) {
        self.browserState = state
    }
    
    func setTab(_ tab: BrowserTab) {
        self.tab = tab
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
        tab?.isLoading = true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
                self.browserState?.updateTitle(title)
                self.tab?.title = title.isEmpty ? "New Tab" : title
            }
        }
        
        // Extract favicon
        extractFavicon(from: webView)
        
        // Make scrollbars transparent using AppKit
        DispatchQueue.main.async {
            if let scrollView = webView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
                scrollView.scrollerStyle = .overlay
                if let verticalScroller = scrollView.verticalScroller {
                    verticalScroller.alphaValue = 0.0
                }
                if let horizontalScroller = scrollView.horizontalScroller {
                    horizontalScroller.alphaValue = 0.0
                }
            }
        }
        
        // Inject CSS to make web content scrollbars transparent
        let scrollbarCSS = """
        (function() {
            var style = document.createElement('style');
            style.textContent = `
                ::-webkit-scrollbar {
                    width: 12px;
                    height: 12px;
                }
                ::-webkit-scrollbar-track {
                    background: transparent;
                }
                ::-webkit-scrollbar-thumb {
                    background: transparent;
                }
                ::-webkit-scrollbar-thumb:hover {
                    background: rgba(0, 0, 0, 0.2);
                }
            `;
            document.head.appendChild(style);
        })();
        """
        webView.evaluateJavaScript(scrollbarCSS, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        browserState?.updateLoadingState(false)
        tab?.isLoading = false
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    // MARK: - Tab Freeze/Pause Methods
    
    func pauseExecution() {
        // Pause JavaScript execution by evaluating a script that stops timers
        let pauseScript = """
        (function() {
            if (window._photonPaused) return;
            window._photonPaused = true;
            
            // Store original setTimeout/setInterval
            window._originalSetTimeout = window.setTimeout;
            window._originalSetInterval = window.setInterval;
            window._originalRequestAnimationFrame = window.requestAnimationFrame;
            
            // Override to prevent execution
            window.setTimeout = function() { return 0; };
            window.setInterval = function() { return 0; };
            window.requestAnimationFrame = function() { return 0; };
            
            // Pause media elements
            document.querySelectorAll('video, audio').forEach(function(media) {
                if (!media.paused) {
                    media.pause();
                    media.dataset._photonWasPlaying = 'true';
                }
            });
        })();
        """
        evaluateJavaScript(pauseScript, completionHandler: nil)
    }
    
    func resumeExecution() {
        // Resume JavaScript execution
        let resumeScript = """
        (function() {
            if (!window._photonPaused) return;
            window._photonPaused = false;
            
            // Restore original functions
            if (window._originalSetTimeout) {
                window.setTimeout = window._originalSetTimeout;
            }
            if (window._originalSetInterval) {
                window.setInterval = window._originalSetInterval;
            }
            if (window._originalRequestAnimationFrame) {
                window.requestAnimationFrame = window._originalRequestAnimationFrame;
            }
            
            // Resume media elements
            document.querySelectorAll('video, audio').forEach(function(media) {
                if (media.dataset._photonWasPlaying === 'true') {
                    media.play().catch(function() {});
                    delete media.dataset._photonWasPlaying;
                }
            });
        })();
        """
        evaluateJavaScript(resumeScript, completionHandler: nil)
    }
    
    // MARK: - Favicon Extraction
    
    private func extractFavicon(from webView: WKWebView) {
        // Try multiple methods to get favicon
        let faviconScript = """
        (function() {
            // Method 1: Check for link rel="icon" or "shortcut icon"
            var faviconLink = document.querySelector('link[rel="icon"], link[rel="shortcut icon"], link[rel="apple-touch-icon"]');
            if (faviconLink && faviconLink.href) {
                return faviconLink.href;
            }
            
            // Method 2: Try common favicon paths
            var baseURL = window.location.origin;
            var commonPaths = ['/favicon.ico', '/favicon.png', '/apple-touch-icon.png'];
            for (var i = 0; i < commonPaths.length; i++) {
                var testURL = baseURL + commonPaths[i];
                // Return the first common path (we'll verify it exists on Swift side)
                return testURL;
            }
            
            // Method 3: Fallback to default favicon path
            return baseURL + '/favicon.ico';
        })();
        """
        
        webView.evaluateJavaScript(faviconScript) { [weak self] result, error in
            guard let self = self, let faviconURLString = result as? String else { return }
            
            // Handle relative URLs
            var faviconURL: URL?
            if let url = URL(string: faviconURLString) {
                if url.scheme != nil {
                    faviconURL = url
                } else if let baseURL = webView.url {
                    faviconURL = URL(string: faviconURLString, relativeTo: baseURL)
                }
            }
            
            guard let finalURL = faviconURL else { return }
            
            // Download and set favicon
            self.loadFavicon(from: finalURL)
        }
    }
    
    private func loadFavicon(from url: URL) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let image = NSImage(data: data) else {
                return
            }
            
            DispatchQueue.main.async {
                // Resize favicon to 16x16 for tab display
                let resizedImage = NSImage(size: NSSize(width: 16, height: 16))
                resizedImage.lockFocus()
                image.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16),
                          from: NSRect.zero,
                          operation: .sourceOver,
                          fraction: 1.0)
                resizedImage.unlockFocus()
                
                self.tab?.favicon = resizedImage
            }
        }
        task.resume()
    }
}
