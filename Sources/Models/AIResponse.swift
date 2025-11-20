import Foundation

struct AIResponse: Codable {
    let response: String
    let relevantURL: String?
    let query: String
    
    init(response: String, relevantURL: String? = nil, query: String) {
        self.response = response
        self.relevantURL = relevantURL
        self.query = query
    }
}

// Notification bubble model (replaces AIResponseCard)
struct AINotification: Identifiable {
    let id = UUID()
    let response: String
    let relevantURL: URL?
    let query: String
    let promptMode: PromptMode?
    let timestamp = Date()
    
    init(response: String, relevantURL: String?, query: String, promptMode: PromptMode? = nil) {
        self.response = response
        self.query = query
        self.promptMode = promptMode
        if let urlString = relevantURL, let url = URL(string: urlString) {
            self.relevantURL = url
        } else {
            self.relevantURL = nil
        }
    }
}

// Legacy support - keep AIResponseCard for backward compatibility during migration
struct AIResponseCard: Identifiable {
    let id = UUID()
    let response: String
    let relevantURL: URL?
    let query: String
    let promptMode: PromptMode?
    let timestamp = Date()
    
    init(response: String, relevantURL: String?, query: String, promptMode: PromptMode? = nil) {
        self.response = response
        self.query = query
        self.promptMode = promptMode
        if let urlString = relevantURL, let url = URL(string: urlString) {
            self.relevantURL = url
        } else {
            self.relevantURL = nil
        }
    }
    
    // Convert to notification
    var notification: AINotification {
        AINotification(
            response: response,
            relevantURL: relevantURL?.absoluteString,
            query: query,
            promptMode: promptMode
        )
    }
}

