import Foundation

/// Photon Search Realtime Service
/// Uses RAG (Retrieval Augmented Generation) to provide real-time AI-powered search
class PhotonSearchService {
    private let aiService: LocalAIService
    private let session = URLSession.shared
    
    init(aiService: LocalAIService) {
        self.aiService = aiService
    }
    
    /// Perform Realtime search: Retrieve relevant web content, then generate AI response
    func search(query: String) async throws -> PhotonSearchResult {
        // Step 1: Retrieve relevant web content using DuckDuckGo Instant Answer API
        let webResults = try await retrieveWebContent(query: query)
        
        // Step 2: Generate AI response using retrieved context
        let aiResponse = try await generateAIResponse(query: query, context: webResults)
        
        return PhotonSearchResult(
            query: query,
            aiResponse: aiResponse.response,
            relevantURLs: aiResponse.relevantURLs,
            webResults: webResults
        )
    }
    
    /// Retrieve relevant web content for the query
    private func retrieveWebContent(query: String) async throws -> [WebSearchResult] {
        // Use DuckDuckGo Instant Answer API for retrieval
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_html=1&skip_disambig=1"
        
        guard let url = URL(string: urlString) else {
            throw PhotonSearchError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PhotonSearchError.invalidResponse
        }
        
        var results: [WebSearchResult] = []
        
        // Extract Abstract (instant answer)
        if let abstract = json["Abstract"] as? String,
           let abstractURL = json["AbstractURL"] as? String,
           !abstract.isEmpty {
            results.append(WebSearchResult(
                title: json["Heading"] as? String ?? "Instant Answer",
                snippet: abstract,
                url: abstractURL
            ))
        }
        
        // Extract Related Topics
        if let relatedTopics = json["RelatedTopics"] as? [[String: Any]] {
            for topic in relatedTopics.prefix(5) {
                if let text = topic["Text"] as? String,
                   let firstURL = topic["FirstURL"] as? String {
                    results.append(WebSearchResult(
                        title: topic["Text"] as? String ?? "Related",
                        snippet: text,
                        url: firstURL
                    ))
                }
            }
        }
        
        // Extract Results
        if let resultsArray = json["Results"] as? [[String: Any]] {
            for result in resultsArray.prefix(5) {
                if let text = result["Text"] as? String,
                   let firstURL = result["FirstURL"] as? String {
                    results.append(WebSearchResult(
                        title: result["Text"] as? String ?? "Result",
                        snippet: text,
                        url: firstURL
                    ))
                }
            }
        }
        
        // If no results, fallback to web search
        if results.isEmpty {
            // Use DuckDuckGo HTML search as fallback
            results.append(WebSearchResult(
                title: "Search Results",
                snippet: "View search results for: \(query)",
                url: "https://duckduckgo.com/?q=\(encodedQuery)"
            ))
        }
        
        return results
    }
    
    /// Generate AI response using retrieved context
    private func generateAIResponse(query: String, context: [WebSearchResult]) async throws -> AIResponseWithURLs {
        // Build context string from web results
        let contextString = context.prefix(3).map { result in
            "Title: \(result.title)\nSnippet: \(result.snippet)\nURL: \(result.url)"
        }.joined(separator: "\n\n")
        
        // Create Realtime prompt
        let ragPrompt = """
        Based on the following retrieved information, provide a comprehensive answer to the user's query.
        
        User Query: \(query)
        
        Retrieved Information:
        \(contextString)
        
        Instructions:
        1. Synthesize the information from the retrieved sources
        2. Provide a clear, accurate answer
        3. Cite relevant URLs when mentioning specific information
        4. If the information is incomplete, mention that and suggest the user visit the source URLs
        
        Answer:
        """
        
        // Use AI service to generate response
        let aiResponse = try await aiService.sendMessage(ragPrompt)
        let response = aiResponse.response
        
        // Extract URLs from context
        let relevantURLs = context.map { URL(string: $0.url) }.compactMap { $0 }
        
        return AIResponseWithURLs(
            response: response,
            relevantURLs: relevantURLs
        )
    }
}

// MARK: - Models

struct PhotonSearchResult {
    let query: String
    let aiResponse: String
    let relevantURLs: [URL]
    let webResults: [WebSearchResult]
}

struct WebSearchResult {
    let title: String
    let snippet: String
    let url: String
}

struct AIResponseWithURLs {
    let response: String
    let relevantURLs: [URL]
}

enum PhotonSearchError: Error {
    case invalidURL
    case invalidResponse
    case aiServiceError(Error)
}

