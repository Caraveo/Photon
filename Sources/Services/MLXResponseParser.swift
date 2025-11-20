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
        
        // Add space after period if followed by letter (no space) - but not for decimals or URLs
        fixed = fixed.replacingOccurrences(
            of: #"\.([A-Z])"#,
            with: ". $1",
            options: .regularExpression
        )
        
        // Add space after period if followed by lowercase letter (but not in URLs or decimals)
        fixed = fixed.replacingOccurrences(
            of: #"([a-z])\.([a-z])"#,
            with: "$1. $2",
            options: .regularExpression
        )
        
        // Add space after comma if followed by letter (no space)
        fixed = fixed.replacingOccurrences(
            of: #",([A-Za-z])"#,
            with: ", $1",
            options: .regularExpression
        )
        
        // Add space after colon if followed by letter (no space)
        fixed = fixed.replacingOccurrences(
            of: #":([A-Za-z])"#,
            with: ": $1",
            options: .regularExpression
        )
        
        // Add space after semicolon if followed by letter (no space)
        fixed = fixed.replacingOccurrences(
            of: #";([A-Za-z])"#,
            with: "; $1",
            options: .regularExpression
        )
        
        // Add space after exclamation if followed by letter (no space)
        fixed = fixed.replacingOccurrences(
            of: #"!([A-Za-z])"#,
            with: "! $1",
            options: .regularExpression
        )
        
        // Add space after question mark if followed by letter (no space)
        fixed = fixed.replacingOccurrences(
            of: #"\?([A-Za-z])"#,
            with: "? $1",
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
        fixed = fixed.replacingOccurrences(
            of: #"([a-z])\n([a-z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Ensure double newlines for paragraphs
        fixed = fixed.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        
        return fixed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

