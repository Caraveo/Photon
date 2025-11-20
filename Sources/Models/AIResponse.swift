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

struct AIResponseCard: Identifiable {
    let id = UUID()
    let response: String
    let relevantURL: URL?
    let query: String
    let timestamp = Date()
    
    init(response: String, relevantURL: String?, query: String) {
        self.response = response
        self.query = query
        if let urlString = relevantURL, let url = URL(string: urlString) {
            self.relevantURL = url
        } else {
            self.relevantURL = nil
        }
    }
}

