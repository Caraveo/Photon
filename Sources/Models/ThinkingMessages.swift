import Foundation

// Creative thinking/reasoning messages for AI generation
struct ThinkingMessages {
    static let messages: [String] = [
        "Reasoning...",
        "Thinking...",
        "Ideas Forming...",
        "Conceptualizing...",
        "Analyzing...",
        "Synthesizing...",
        "Connecting Dots...",
        "Exploring Concepts...",
        "Building Understanding...",
        "Processing Information...",
        "Forming Insights...",
        "Weaving Thoughts...",
        "Crafting Response...",
        "Assembling Ideas...",
        "Refining Thoughts...",
        "Deep Diving...",
        "Pattern Matching...",
        "Drawing Conclusions...",
        "Structuring Knowledge...",
        "Evaluating Options...",
        "Integrating Perspectives...",
        "Unfolding Logic...",
        "Crystallizing Ideas...",
        "Mapping Connections...",
        "Distilling Wisdom..."
    ]
    
    static func random() -> String {
        messages.randomElement() ?? "Thinking..."
    }
    
    static func at(index: Int) -> String {
        messages[index % messages.count]
    }
}

