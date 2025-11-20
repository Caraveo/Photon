import Foundation
import Combine

class LocalAIService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    
    private let baseURL: URL
    private let session: URLSession
    private var metalBridge: MetalBridge?
    
    init() {
        // Default to localhost:6000 for Mistral AI (based on memory)
        self.baseURL = URL(string: "http://localhost:6000")!
        self.session = URLSession.shared
        self.metalBridge = MetalBridge()
    }
    
    func connect() {
        // Check if Mistral AI service is running
        Task {
            do {
                let healthURL = baseURL.appendingPathComponent("health")
                let (_, response) = try await session.data(from: healthURL)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run {
                        self.isConnected = true
                        self.connectionStatus = "Connected"
                    }
                } else {
                    await MainActor.run {
                        self.isConnected = false
                        self.connectionStatus = "Service not available"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                    self.connectionStatus = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func sendMessage(_ message: String) async throws -> AIResponse {
        guard isConnected else {
            throw AIError.notConnected
        }
        
        // Use METAL bridge for communication
        if let bridge = metalBridge {
            let response = try await bridge.sendToAI(message: message)
            let relevantURL = try await findRelevantURL(for: message, response: response)
            return AIResponse(response: response, relevantURL: relevantURL, query: message)
        }
        
        // Fallback to direct HTTP
        return try await sendHTTPRequest(message: message)
    }
    
    private func sendHTTPRequest(message: String) async throws -> AIResponse {
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "mistral",
            "messages": [
                [
                    "role": "user",
                    "content": message
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageObj = firstChoice["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        // Find relevant URL based on the query and response
        let relevantURL = try await findRelevantURL(for: message, response: content)
        
        return AIResponse(response: content, relevantURL: relevantURL, query: message)
    }
    
    /// Find the most relevant URL for a given query and AI response
    private func findRelevantURL(for query: String, response: String) async throws -> String? {
        // Strategy 1: Extract URLs from the AI response
        if let urlInResponse = extractURL(from: response) {
            return urlInResponse
        }
        
        // Strategy 2: Search for URLs based on keywords in the query
        if let searchURL = try await searchURL(for: query) {
            return searchURL
        }
        
        // Strategy 3: Use DuckDuckGo instant answer API or similar
        return try await searchDuckDuckGo(query: query)
    }
    
    /// Extract URL from text using regex
    private func extractURL(from text: String) -> String? {
        let urlPattern = #"https?://[^\s]+"#
        let regex = try? NSRegularExpression(pattern: urlPattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range),
           let urlRange = Range(match.range, in: text) {
            let urlString = String(text[urlRange])
            // Validate URL
            if URL(string: urlString) != nil {
                return urlString
            }
        }
        
        return nil
    }
    
    /// Search for URL based on query keywords
    private func searchURL(for query: String) async throws -> String? {
        // Extract key terms from query
        let keywords = extractKeywords(from: query)
        guard !keywords.isEmpty else { return nil }
        
        // Try to construct a search URL (e.g., Wikipedia, official docs)
        // This is a simple heuristic - in production, you'd use a proper search API
        let searchTerms = keywords.joined(separator: "+")
        
        // Try Wikipedia first
        if let wikiURL = URL(string: "https://en.wikipedia.org/wiki/\(searchTerms)"),
           await urlExists(wikiURL) {
            return wikiURL.absoluteString
        }
        
        return nil
    }
    
    /// Search using DuckDuckGo instant answer API
    private func searchDuckDuckGo(query: String) async throws -> String? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_html=1&skip_disambig=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await session.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let abstractURL = json["AbstractURL"] as? String,
               !abstractURL.isEmpty {
                return abstractURL
            }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["Results"] as? [[String: Any]],
               let firstResult = results.first,
               let firstURL = firstResult["FirstURL"] as? String {
                return firstURL
            }
        } catch {
            // Silently fail - URL search is optional
        }
        
        return nil
    }
    
    /// Extract keywords from query
    private func extractKeywords(from query: String) -> [String] {
        let stopWords = Set(["what", "is", "the", "a", "an", "how", "why", "when", "where", "who", "which", "do", "does", "did", "can", "could", "should", "would", "will", "to", "of", "in", "on", "at", "for", "with", "about", "as", "by"])
        
        return query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count > 2 }
            .prefix(3)
            .map { $0.capitalized.replacingOccurrences(of: " ", with: "_") }
    }
    
    /// Check if URL exists
    private func urlExists(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }
        
        return false
    }
}

enum AIError: LocalizedError {
    case notConnected
    case requestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Mistral AI service"
        case .requestFailed:
            return "Request to AI service failed"
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}

