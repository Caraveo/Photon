import Foundation
import Combine

class LocalAIService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var availableModels: [AIModel] = []
    
    private var session: URLSession
    private var metalBridge: MetalBridge?
    var settings: AISettings
    var connectionTask: Task<Void, Never>?
    
    init(settings: AISettings = AISettings()) {
        self.session = URLSession.shared
        self.metalBridge = MetalBridge()
        self.settings = settings
        self.availableModels = AIModel.defaultModels
    }
    
    deinit {
        connectionTask?.cancel()
    }
    
    func connect() {
        // Cancel any existing connection task
        connectionTask?.cancel()
        
        connectionTask = Task { [weak self] in
            guard let self = self else { return }
            await self.checkConnection()
            await self.fetchAvailableModels()
        }
    }
    
    private func checkConnection() async {
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        let provider = settings.selectedProvider
        guard let baseURL = URL(string: provider.baseURL) else {
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isConnected = false
                self.connectionStatus = "Invalid base URL"
            }
            return
        }
        
        switch provider {
        case .mlx:
            // Check MLX service
            do {
                let modelsURL = baseURL.appendingPathComponent("v1/models")
                let (_, response) = try await session.data(from: modelsURL)
                
                guard !Task.isCancelled else { return }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run { [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        self.isConnected = true
                        self.connectionStatus = "Connected to MLX"
                    }
                    return
                }
            } catch {
                // Try health endpoint
            }
            
            guard !Task.isCancelled else { return }
            
            do {
                let healthURL = baseURL.appendingPathComponent("health")
                let (_, response) = try await session.data(from: healthURL)
                
                guard !Task.isCancelled else { return }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run { [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        self.isConnected = true
                        self.connectionStatus = "Connected to MLX"
                    }
                    return
                }
            } catch {}
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isConnected = false
                self.connectionStatus = "MLX service not available"
            }
            
        case .openai:
            // Check OpenAI - just verify key is set
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                if !self.settings.openAIKey.isEmpty {
                    self.isConnected = true
                    self.connectionStatus = "OpenAI ready"
                } else {
                    self.isConnected = false
                    self.connectionStatus = "OpenAI key not set"
                }
            }
            
        case .mistral:
            // Check Mistral - verify key is set
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                if !self.settings.mistralKey.isEmpty {
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
                
                guard !Task.isCancelled else { return }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run { [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        self.isConnected = true
                        self.connectionStatus = "Connected to Ollama"
                    }
                    return
                }
            } catch {
                // Try health endpoint as fallback
            }
            
            guard !Task.isCancelled else { return }
            
            do {
                let healthURL = baseURL.appendingPathComponent("api/version")
                let (_, response) = try await session.data(from: healthURL)
                
                guard !Task.isCancelled else { return }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run { [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        self.isConnected = true
                        self.connectionStatus = "Connected to Ollama"
                    }
                    return
                }
            } catch {}
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isConnected = false
                self.connectionStatus = "Ollama service not available"
            }
        }
    }
    
    func fetchAvailableModels() async {
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        let provider = settings.selectedProvider
        guard let baseURL = URL(string: provider.baseURL) else {
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.availableModels = AIModel.defaultModels
                self.settings.availableModels = AIModel.defaultModels
            }
            return
        }
        
        switch provider {
        case .mlx:
            // Fetch models from MLX
            do {
                let modelsURL = baseURL.appendingPathComponent("v1/models")
                let (data, response) = try await session.data(from: modelsURL)
                
                guard !Task.isCancelled else { return }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modelsData = json["data"] as? [[String: Any]] {
                    
                    let models = modelsData.compactMap { modelData -> AIModel? in
                        guard let id = modelData["id"] as? String else { return nil }
                        let name = modelData["id"] as? String ?? id
                        return AIModel(id: id, name: name, provider: .mlx)
                    }
                    
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        // Merge with defaults
                        var allModels = AIModel.defaultModels.filter { $0.provider != .mlx }
                        allModels.append(contentsOf: models)
                        self.availableModels = allModels
                        // Also update settings availableModels so saved models can be loaded
                        self.settings.availableModels = allModels
                    }
                }
            } catch {
                // Failed to fetch MLX models
                guard !Task.isCancelled else { return }
            }
            
        case .ollama:
            // Fetch models from Ollama
            do {
                let tagsURL = baseURL.appendingPathComponent("api/tags")
                let (data, response) = try await session.data(from: tagsURL)
                
                guard !Task.isCancelled else { return }
                
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
                    
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        // Merge with defaults
                        var allModels = AIModel.defaultModels.filter { $0.provider != .ollama }
                        allModels.append(contentsOf: models)
                        self.availableModels = allModels
                        // Also update settings availableModels so saved models can be loaded
                        self.settings.availableModels = allModels
                    }
                }
            } catch {
                // Failed to fetch Ollama models
                guard !Task.isCancelled else { return }
            }
            
        case .openai, .mistral:
            // Use default models for OpenAI and Mistral
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.availableModels = AIModel.defaultModels
                // Also update settings availableModels
                self.settings.availableModels = AIModel.defaultModels
            }
        }
    }
    
    func sendMessage(_ message: String, systemPrompt: String? = nil, model: AIModel? = nil) async throws -> AIResponse {
        // Don't auto-connect - user must connect manually
        guard isConnected else {
            let provider = settings.selectedProvider
            let errorMsg = provider == .mlx ? "MLX service not available. Please connect in Settings or make sure MLX is running on http://localhost:11973" :
                          provider == .ollama ? "Ollama service not available. Please connect in Settings or make sure Ollama is running on http://localhost:11434" :
                          provider == .openai ? "OpenAI API key not set. Please set it in Settings." :
                          "Mistral API key not set. Please set it in Settings."
            throw AIError.notConnectedWithMessage(errorMsg)
        }
        
        let selectedModel = model ?? settings.selectedModel
        let provider = settings.selectedProvider
        
        switch provider {
        case .mlx:
            return try await sendMLXRequest(message: message, systemPrompt: systemPrompt, model: selectedModel)
        case .ollama:
            return try await sendOllamaRequest(message: message, systemPrompt: systemPrompt, model: selectedModel)
        case .openai:
            return try await sendOpenAIRequest(message: message, systemPrompt: systemPrompt, model: selectedModel)
        case .mistral:
            return try await sendMistralRequest(message: message, systemPrompt: systemPrompt, model: selectedModel)
        }
    }
    
    // Streaming version for MLX
    func sendStreamingMessage(_ message: String, systemPrompt: String? = nil, model: AIModel? = nil, onChunk: @escaping (String) async -> Void) async throws {
        guard isConnected else {
            let provider = settings.selectedProvider
            let errorMsg = provider == .mlx ? "MLX service not available. Please connect in Settings or make sure MLX is running on http://localhost:11973" :
                          provider == .ollama ? "Ollama service not available. Please connect in Settings or make sure Ollama is running on http://localhost:11434" :
                          provider == .openai ? "OpenAI API key not set. Please set it in Settings." :
                          "Mistral API key not set. Please set it in Settings."
            throw AIError.notConnectedWithMessage(errorMsg)
        }
        
        let selectedModel = model ?? settings.selectedModel
        let provider = settings.selectedProvider
        
        if provider == .mlx {
            try await sendMLXStreamingRequest(message: message, systemPrompt: systemPrompt, model: selectedModel, onChunk: onChunk)
        } else {
            // For non-MLX providers, fall back to regular request
            let response = try await sendMessage(message, systemPrompt: systemPrompt, model: selectedModel)
            await onChunk(response.response)
        }
    }
    
    private func sendMLXRequest(message: String, systemPrompt: String? = nil, model: AIModel) async throws -> AIResponse {
        guard let baseURL = URL(string: AIProvider.mlx.baseURL) else {
            throw AIError.requestFailed
        }
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build messages array with optional system prompt
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": message])
        
        let requestBody: [String: Any] = [
            "model": model.id == "mlx-default" ? "" : model.id,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1000,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.requestFailed
            }
            
            guard httpResponse.statusCode == 200 else {
                // Try to get error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    throw AIError.notConnectedWithMessage(message)
                }
                throw AIError.requestFailed
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let messageObj = firstChoice["message"] as? [String: Any],
                  let content = messageObj["content"] as? String else {
                throw AIError.invalidResponse
            }
            
            // Parse MLX response to extract reasoning and answer sections
            let parsed = MLXResponseParser.parse(content)
            
            // Use the answer section (or full content if no markers found)
            let answer = parsed.answer.isEmpty ? (parsed.reasoning.isEmpty ? content : parsed.reasoning) : parsed.answer
            
            let relevantURL = try await findRelevantURL(for: message, response: answer)
            return AIResponse(response: answer, relevantURL: relevantURL, query: message)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.requestFailed
        }
    }
    
    // Streaming version for MLX
    private func sendMLXStreamingRequest(message: String, systemPrompt: String? = nil, model: AIModel, onChunk: @escaping (String) async -> Void) async throws {
        guard let baseURL = URL(string: AIProvider.mlx.baseURL) else {
            throw AIError.requestFailed
        }
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // Build messages array with optional system prompt
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": message])
        
        let requestBody: [String: Any] = [
            "model": model.id == "mlx-default" ? "" : model.id,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1000,
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            // Use URLSession's async bytes API for streaming
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.requestFailed
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIError.requestFailed
            }
            
            var accumulatedContent = ""
            
            // Process SSE stream line by line
            for try await line in asyncBytes.lines {
                guard !Task.isCancelled else { return }
                
                // Skip empty lines (SSE format uses empty lines as separators)
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty {
                    continue
                }
                
                // Process SSE data lines
                if trimmedLine.hasPrefix("data: ") {
                    let jsonString = String(trimmedLine.dropFirst(6))
                    
                    // Check for done marker
                    if jsonString == "[DONE]" {
                        break
                    }
                    
                    // Skip if empty
                    if jsonString.isEmpty {
                        continue
                    }
                    
                    // Parse JSON
                    guard let jsonData = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let delta = firstChoice["delta"] as? [String: Any] else {
                        continue
                    }
                    
                    // Content is optional (might be nil in finish_reason chunks)
                    guard let content = delta["content"] as? String, !content.isEmpty else {
                        // Check if this is a finish event
                        if let finishReason = delta["finish_reason"] as? String {
                            // Stream is complete
                            break
                        }
                        continue
                    }
                    
                    // Accumulate the full response
                    accumulatedContent += content
                    
                    // Stream the content chunk immediately
                    await onChunk(content)
                }
            }
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.requestFailed
        }
    }
    
    private func sendOpenAIRequest(message: String, systemPrompt: String? = nil, model: AIModel) async throws -> AIResponse {
        guard !settings.openAIKey.isEmpty else {
            throw AIError.notConnected
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
        
        // Build messages array with optional system prompt
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": message])
        
        let requestBody: [String: Any] = [
            "model": model.id,
            "messages": messages,
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
    
    private func sendOllamaRequest(message: String, systemPrompt: String? = nil, model: AIModel) async throws -> AIResponse {
        guard let baseURL = URL(string: AIProvider.ollama.baseURL) else {
            throw AIError.requestFailed
        }
        let url = baseURL.appendingPathComponent("api/chat")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build messages array with optional system prompt
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": message])
        
        let requestBody: [String: Any] = [
            "model": model.id,
            "messages": messages,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.requestFailed
            }
            
            guard httpResponse.statusCode == 200 else {
                // Try to get error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    throw AIError.notConnectedWithMessage(errorMessage)
                }
                throw AIError.requestFailed
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messageObj = json["message"] as? [String: Any],
                  let content = messageObj["content"] as? String else {
                throw AIError.invalidResponse
            }
            
            let relevantURL = try await findRelevantURL(for: message, response: content)
            return AIResponse(response: content, relevantURL: relevantURL, query: message)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.requestFailed
        }
    }
    
    private func sendMistralRequest(message: String, systemPrompt: String? = nil, model: AIModel) async throws -> AIResponse {
        guard !settings.mistralKey.isEmpty else {
            throw AIError.notConnected
        }
        
        let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.mistralKey)", forHTTPHeaderField: "Authorization")
        
        // Build messages array with optional system prompt
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": message])
        
        let requestBody: [String: Any] = [
            "model": model.id,
            "messages": messages,
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
    func findRelevantURL(for query: String, response: String) async throws -> String? {
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
    case notConnectedWithMessage(String)
    case requestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to AI service"
        case .notConnectedWithMessage(let message):
            return message
        case .requestFailed:
            return "Request to AI service failed"
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}

