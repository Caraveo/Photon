import Foundation

enum SearchEngine: String, CaseIterable, Identifiable {
    case duckduckgo = "DuckDuckGo"
    case google = "Google"
    case photon = "Photon Search"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .duckduckgo:
            return "magnifyingglass"
        case .google:
            return "globe"
        case .photon:
            return "sparkles"
        }
    }
    
    var logoImageName: String? {
        switch self {
        case .duckduckgo:
            return "DuckDuckGo"
        case .google:
            return "Google"
        case .photon:
            return nil // Use SF Symbol for Photon
        }
    }
    
    var description: String {
        switch self {
        case .duckduckgo:
            return "Privacy-focused search engine"
        case .google:
            return "Fast and comprehensive search"
        case .photon:
            return "AI-powered Realtime search"
        }
    }
    
    func buildSearchURL(query: String) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        switch self {
        case .duckduckgo:
            return "https://duckduckgo.com/?q=\(encodedQuery)"
        case .google:
            return "https://www.google.com/search?q=\(encodedQuery)"
        case .photon:
            // Photon Search uses AI, not a URL
            return ""
        }
    }
}

