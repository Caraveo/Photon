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
    private static func fixSpacing(_ text: String) -> String {
        var fixed = text
        
        // Add space after period if followed by letter (no space)
        fixed = fixed.replacingOccurrences(
            of: #"\.([A-Za-z])"#,
            with: ". $1",
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
        
        return fixed
    }
}

