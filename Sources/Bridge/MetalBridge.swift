import Foundation
import JavaScriptCore

/// METAL Bridge for Swift/TypeScript communication
/// This bridge enables communication between Swift and TypeScript layers
class MetalBridge {
    private var jsContext: JSContext?
    private let bridgeScript: String
    
    init() {
        // Initialize JavaScript context for TypeScript bridge
        self.jsContext = JSContext()
        // Load bridge script inline
        self.bridgeScript = """
        // METAL Bridge TypeScript Interface
        class MetalBridge {
            constructor() {
                this.messageQueue = [];
                this.isReady = false;
            }
            
            async sendToAI(message) {
                return new Promise((resolve, reject) => {
                    // Queue message for Swift processing
                    this.messageQueue.push({ message, resolve, reject });
                    // Trigger Swift handler
                    if (window.swiftBridge) {
                        window.swiftBridge.handleMessage(message);
                    }
                });
            }
            
            receiveFromSwift(response) {
                // Handle response from Swift
                if (this.messageQueue.length > 0) {
                    const { resolve } = this.messageQueue.shift();
                    resolve(response);
                }
            }
        }
        
        window.metalBridge = new MetalBridge();
        """
        setupBridge()
    }
    
    
    private func setupBridge() {
        guard let context = jsContext else { return }
        
        // Evaluate bridge script
        context.evaluateScript(bridgeScript)
        
        // Expose Swift functions to JavaScript
        let swiftBridge: @convention(block) (String) -> Void = { [weak self] message in
            Task {
                await self?.handleMessageFromJS(message: message)
            }
        }
        
        context.setObject(swiftBridge, forKeyedSubscript: "swiftBridge" as NSString)
        
        // Error handler
        context.exceptionHandler = { context, exception in
            print("JS Error: \(exception?.toString() ?? "Unknown error")")
        }
    }
    
    func sendToAI(message: String) async throws -> String {
        // For now, use direct HTTP call
        // In full implementation, this would use the JS bridge
        return try await sendDirectRequest(message: message)
    }
    
    private func sendDirectRequest(message: String) async throws -> String {
        let url = URL(string: "http://localhost:6000/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "mistral",
            "messages": [
                ["role": "user", "content": message]
            ],
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let messageObj = choices.first?["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content
    }
    
    private func handleMessageFromJS(message: String) async {
        // Handle messages from JavaScript/TypeScript layer
        print("Received from JS: \(message)")
    }
    
    func injectIntoWebView(_ webView: WKWebView) {
        // Load TypeScript bridge from file
        if let bridgePath = Bundle.main.path(forResource: "typescript-bridge", ofType: "js"),
           let bridgeContent = try? String(contentsOfFile: bridgePath) {
            let script = WKUserScript(
                source: bridgeContent,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
            webView.configuration.userContentController.addUserScript(script)
        } else {
            // Fallback: inject inline script
            let script = WKUserScript(
                source: bridgeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
            webView.configuration.userContentController.addUserScript(script)
        }
    }
}

// Import WebKit for WKWebView
import WebKit

