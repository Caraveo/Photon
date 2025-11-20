import Foundation
import WebKit

class BrowserTab: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String = "New Tab"
    @Published var url: URL?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var aiResponseCards: [AIResponseCard] = []
    @Published var isProcessingAI: Bool = false
    @Published var favicon: NSImage?
    var webView: BrowserWebView?
    
    init(url: URL? = nil) {
        self.url = url
    }
    
    func setWebView(_ webView: BrowserWebView) {
        self.webView = webView
    }
    
    func navigate(to urlString: String) {
        guard let url = URL(string: urlString) else {
            if let urlWithScheme = URL(string: "https://\(urlString)") {
                self.url = urlWithScheme
                webView?.load(url: urlWithScheme)
            }
            return
        }
        self.url = url
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
    
    func pause() {
        // Pause JavaScript execution and media playback
        webView?.pauseExecution()
    }
    
    func resume() {
        // Resume JavaScript execution and media playback
        webView?.resumeExecution()
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabId: UUID?
    
    var activeTab: BrowserTab? {
        tabs.first { $0.id == activeTabId }
    }
    
    init() {
        // Create initial tab
        let initialTab = BrowserTab()
        tabs.append(initialTab)
        activeTabId = initialTab.id
    }
    
    func createNewTab(url: URL? = nil) {
        let newTab = BrowserTab(url: url)
        tabs.append(newTab)
        activeTabId = newTab.id
    }
    
    func closeTab(_ tab: BrowserTab) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.remove(at: index)
            
            // If we closed the active tab, switch to another
            if tab.id == activeTabId {
                if tabs.isEmpty {
                    // Create a new tab if all are closed
                    createNewTab()
                } else {
                    // Switch to the tab at the same index, or the last tab
                    let newIndex = min(index, tabs.count - 1)
                    activeTabId = tabs[newIndex].id
                }
            }
        }
    }
    
    func switchToTab(_ tab: BrowserTab) {
        // Pause the previously active tab
        if let previousTab = activeTab, previousTab.id != tab.id {
            previousTab.pause()
        }
        
        // Resume the new active tab
        tab.resume()
        
        activeTabId = tab.id
    }
}

