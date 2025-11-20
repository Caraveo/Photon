import Foundation
import Combine

class LocalAIService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var availableModels: [AIModel] = []
    
    private var session: URLSession
    private var metalBridge: MetalBridge?
    var settings: AISettings
    
    init(settings: AISettings = AISettings()) {
        self.session = URLSession.shared
        self.metalBridge = MetalBridge()
        self.settings = settings
        self.availableModels = AIModel.defaultModels
    }
    
    func connect() {
        Task {
            await checkConnection()
            await fetchAvailableModels()
        }
    }
    
    private func checkConnection() async {
        let provider = settings.selectedProvider
        let baseURL = URL(string: provider.baseURL)!
        
        switch provider {
        case .mlx:
            // Check MLX service
            do {
                let modelsURL = baseURL.appendingPathComponent("v1/models")
                let (_, response) = try await session.data(from: modelsURL)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run {
                        self.isConnected = true
                        self.connectionStatus = "Connected to MLX"
                    }
                    return
                }
            } catch {
                // Try health endpoint
            }
            
            do {
                let healthURL = baseURL.appendingPathComponent("health")
                let (_, response) = try await session.data(from: healthURL)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run {
                        self.isConnected = true
                        self.connectionStatus = "Connected to MLX"
                    }
                    return
                }
            } catch {}
            
            await MainActor.run {
                self.isConnected = false
                self.connectionStatus = "MLX service not available"
            }
            
        case .openai:
            // Check OpenAI - just verify key is set
            await MainActor.run {
                if !settings.openAIKey.isEmpty {
                    self.isConnected = true
                    self.connectionStatus = "OpenAI ready"
                } else {
                    self.isConnected = false
                    self.connectionStatus = "OpenAI key not set"
                }
            }
            
        case .mistral:
            // Check Mistral - verify key is set
            await MainActor.run {
                if !settings.mistralKey.isEmpty {
                    self.isConnected = true
                    self.connectionStatus = "Mistral AI ready"
                } else {
                    self.isConnected = false
                    self.connectionStatus = "Mistral key not set"
                }
            }
            
        case .ollama:
            // Check Ollama service
            do {
                let tagsURL = baseURL.appendingPathComponent("api/tags")
                let (_, response) = try await session.data(from: tagsURL)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run {
                        self.isConnected = true
                        self.connectionStatus = "Connected to Ollama"
                    }
                    return
                }
            } catch {
                // Try health endpoint as fallback
            }
            
            do {
                let healthURL = baseURL.appendingPathComponent("api/version")
                let (_, response) = try await session.data(from: healthURL)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run {
                        self.isConnected = true
                        self.connectionStatus = "Connected to Ollama"
                    }
                    return
                }
            } catch {}
            
            await MainActor.run {
                self.isConnected = false
                self.connectionStatus = "Ollama service not available"
            }
        }
    }
    
    func fetchAvailableModels() async {
        let provider = settings.selectedProvider
        let baseURL = URL(string: provider.baseURL)!
        
        switch provider {
        case .mlx:
            // Fetch models from MLX
            do {
                let modelsURL = baseURL.appendingPathComponent("v1/models")
                let (data, response) = try await session.data(from: modelsURL)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modelsData = json["data"] as? [[String: Any]] {
                    
                    let models = modelsData.compactMap { modelData -> AIModel? in
                        guard let id = modelData["id"] as? String else { return nil }
                        let name = modelData["id"] as? String ?? id
                        return AIModel(id: id, name: name, provider: .mlx)
                    }
                    
                    await MainActor.run {
                        // Merge with defaults
                        var allModels = AIModel.defaultModels.filter { $0.provider != .mlx }
                        allModels.append(contentsOf: models)
                        self.availableModels = allModels
                    }
                }
            } catch {
                print("⚠️ [DEBUG] Failed to fetch MLX models: \(error.localizedDescription)")
            }
            
        case .ollama:
            // Fetch models from Ollama
            do {
                let tagsURL = baseURL.appendingPathComponent("api/tags")
                let (data, response) = try await session.data(from: tagsURL)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modelsData = json["models"] as? [[String: Any]] {
                    
                    let models = modelsData.compactMap { modelData -> AIModel? in
                        guard let name = modelData["name"] as? String else { return nil }
                        // Ollama model names can include tags like "llama2:latest" or just "llama2"
                        let modelId = name
                        let displayName = name.replacingOccurrences(of: ":latest", with: "").capitalized
                        return AIModel(id: modelId, name: displayName, provider: .ollama)
                    }
                    
                    await MainActor.run {
                        // Merge with defaults
                        var allModels = AIModel.defaultModels.filter { $0.provider != .ollama }
                        allModels.append(contentsOf: models)
                        self.availableModels = allModels
                    }
                }
            } catch {
                print("⚠️ [DEBUG] Failed to fetch Ollama models: \(error.localizedDescription)")
            }
            
        case .openai, .mistral:
            // Use default models for OpenAI and Mistral
            await MainActor.run {
                self.availableModels = AIModel.defaultModels
            }
        }
    }
    
    func sendMessage(_ message: String, model: AIModel? = nil) async throws -> AIResponse {
        guard isConnected else {
            throw AIError.notConnected
        }
        
        let selectedModel = model ?? settings.selectedModel
        let provider = settings.selectedProvider
        
        switch provider {
        case .mlx:
            return try await sendMLXRequest(message: message, model: selectedModel)
        case .ollama:
            return try await sendOllamaRequest(message: message, model: selectedModel)
        case .openai:
            return try await sendOpenAIRequest(message: message, model: selectedModel)
        case .mistral:
            return try await sendMistralRequest(message: message, model: selectedModel)
        }
    }
    
    private func sendMLXRequest(message: String, model: AIModel) async throws -> AIResponse {
        let baseURL = URL(string: AIProvider.mlx.baseURL)!
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model.id == "mlx-default" ? "" : model.id,
            "messages": [
                ["role": "user", "content": message]
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
        
        let relevantURL = try await findRelevantURL(for: message, response: content)
        return AIResponse(response: content, relevantURL: relevantURL, query: message)
    }
    
    private func sendOpenAIRequest(message: String, model: AIModel) async throws -> AIResponse {
        guard !settings.openAIKey.isEmpty else {
            throw AIError.notConnected
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": model.id,
            "messages": [
                ["role": "user", "content": message]
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
        
        let relevantURL = try await findRelevantURL(for: message, response: content)
        return AIResponse(response: content, relevantURL: relevantURL, query: message)
    }
    
    private func sendOllamaRequest(message: String, model: AIModel) async throws -> AIResponse {
        let baseURL = URL(string: AIProvider.ollama.baseURL)!
        let url = baseURL.appendingPathComponent("api/chat")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model.id,
            "messages": [
                ["role": "user", "content": message]
            ],
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageObj = json["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        let relevantURL = try await findRelevantURL(for: message, response: content)
        return AIResponse(response: content, relevantURL: relevantURL, query: message)
    }
    
    private func sendMistralRequest(message: String, model: AIModel) async throws -> AIResponse {
        guard !settings.mistralKey.isEmpty else {
            throw AIError.notConnected
        }
        
        let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.mistralKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": model.id,
            "messages": [
                ["role": "user", "content": message]
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
            return "Not connected to MLX service"
        case .requestFailed:
            return "Request to AI service failed"
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}

