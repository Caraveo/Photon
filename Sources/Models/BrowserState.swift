import Foundation
import Combine

class BrowserState: ObservableObject {
    @Published var currentURL: URL?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var pageTitle: String = ""
    
    private var webView: BrowserWebView?
    
    func setWebView(_ webView: BrowserWebView) {
        self.webView = webView
    }
    
    func navigate(to urlString: String) {
        guard let url = URL(string: urlString) else {
            // Try adding https:// if no scheme
            if let urlWithScheme = URL(string: "https://\(urlString)") {
                currentURL = urlWithScheme
                webView?.load(url: urlWithScheme)
            }
            return
        }
        currentURL = url
        webView?.load(url: url)
    }
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    func reload() {
        webView?.reload()
    }
    
    func updateNavigationState(canGoBack: Bool, canGoForward: Bool) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
    
    func updateLoadingState(_ isLoading: Bool) {
        self.isLoading = isLoading
    }
    
    func updateTitle(_ title: String) {
        self.pageTitle = title
    }
}

