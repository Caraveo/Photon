import Foundation

// Parser for MLX responses that include [Reasoning] and [Answer] sections
struct MLXResponseParser {
    /// Parse MLX response and extract reasoning and answer sections
    static func parse(_ response: String) -> (reasoning: String, answer: String) {
        // Look for [Reasoning] and [Answer] markers
        let reasoningMarker = "[Reasoning]"
        let answerMarker = "[Answer]"
        
        var reasoning = ""
        var answer = response // Default to full response if no markers found
        
        if let reasoningRange = response.range(of: reasoningMarker),
           let answerRange = response.range(of: answerMarker) {
            // Extract reasoning section
            let reasoningStart = response.index(reasoningRange.upperBound, offsetBy: 0)
            let reasoningEnd = answerRange.lowerBound
            reasoning = String(response[reasoningStart..<reasoningEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract answer section
            let answerStart = response.index(answerRange.upperBound, offsetBy: 0)
            answer = String(response[answerStart...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let reasoningRange = response.range(of: reasoningMarker) {
            // Only reasoning marker found
            let reasoningStart = response.index(reasoningRange.upperBound, offsetBy: 0)
            reasoning = String(response[reasoningStart...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            answer = ""
        }
        
        // Fix spacing issues: add space after periods if missing
        answer = fixSpacing(answer)
        
        return (reasoning: reasoning, answer: answer)
    }
    
    /// Fix spacing issues in text (add space after periods, etc.)
    static func fixSpacing(_ text: String) -> String {
        var fixed = text
        
        // More aggressive spacing fixes - handle all punctuation followed by letters
        
        // Period followed by any letter (uppercase or lowercase)
        fixed = fixed.replacingOccurrences(
            of: #"\.([A-Za-z])"#,
            with: ". $1",
            options: .regularExpression
        )
        
        // Comma followed by any letter
        fixed = fixed.replacingOccurrences(
            of: #",([A-Za-z])"#,
            with: ", $1",
            options: .regularExpression
        )
        
        // Colon followed by any letter
        fixed = fixed.replacingOccurrences(
            of: #":([A-Za-z])"#,
            with: ": $1",
            options: .regularExpression
        )
        
        // Semicolon followed by any letter
        fixed = fixed.replacingOccurrences(
            of: #";([A-Za-z])"#,
            with: "; $1",
            options: .regularExpression
        )
        
        // Exclamation followed by any letter
        fixed = fixed.replacingOccurrences(
            of: #"!([A-Za-z])"#,
            with: "! $1",
            options: .regularExpression
        )
        
        // Question mark followed by any letter
        fixed = fixed.replacingOccurrences(
            of: #"\?([A-Za-z])"#,
            with: "? $1",
            options: .regularExpression
        )
        
        // Closing parenthesis followed by any letter
        fixed = fixed.replacingOccurrences(
            of: #"\)([A-Za-z])"#,
            with: ") $1",
            options: .regularExpression
        )
        
        // Closing bracket followed by any letter
        fixed = fixed.replacingOccurrences(
            of: #"\]([A-Za-z])"#,
            with: "] $1",
            options: .regularExpression
        )
        
        // Closing brace followed by any letter
        fixed = fixed.replacingOccurrences(
            of: #"\}([A-Za-z])"#,
            with: "} $1",
            options: .regularExpression
        )
        
        // Fix multiple spaces (but preserve intentional line breaks)
        fixed = fixed.replacingOccurrences(
            of: #" {2,}"#,
            with: " ",
            options: .regularExpression
        )
        
        // Ensure proper paragraph breaks (double newlines)
        // Convert single newlines in the middle of sentences to spaces
        // But preserve double newlines for paragraphs
        fixed = fixed.replacingOccurrences(
            of: #"([a-z,\.!?;:\)\]\}])\n([a-z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Ensure double newlines for paragraphs (normalize multiple newlines)
        fixed = fixed.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        
        // Clean up any trailing spaces before newlines
        fixed = fixed.replacingOccurrences(
            of: #" +\n"#,
            with: "\n",
            options: .regularExpression
        )
        
        return fixed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

