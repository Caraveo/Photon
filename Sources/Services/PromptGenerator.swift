import Foundation

enum PromptMode: String, CaseIterable {
    case concise = "Concise"
    case detailed = "Detailed"
    case creative = "Creative"
    
    func generatePrompt(from query: String) -> String {
        switch self {
        case .concise:
            return "Provide a brief, direct answer to: \(query)"
        case .detailed:
            return "Provide a comprehensive, detailed explanation about: \(query). Include relevant context and examples."
        case .creative:
            return "Provide an engaging, insightful response about: \(query). Make it interesting and thought-provoking."
        }
    }
}

class PromptGenerator {
    static func generatePrompts(from query: String) -> [(mode: PromptMode, prompt: String)] {
        return PromptMode.allCases.map { mode in
            (mode: mode, prompt: mode.generatePrompt(from: query))
        }
    }
}

