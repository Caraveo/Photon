import SwiftUI

// Beautiful markdown rendering view with enhanced formatting
struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Process text to handle newlines and spacing properly
            let processedText = processText(text)
            
            // Parse and render markdown with full syntax support
            if let attributedString = try? AttributedString(markdown: processedText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)) {
                // Apply custom styling to the markdown with 1.2 line spacing
                // Line spacing = (fontSize * 1.2) - fontSize = fontSize * 0.2
                // For 14px font: 14 * 0.2 = 2.8px spacing
                Text(attributedString)
                    .font(.system(size: 14, design: .default))
                    .lineSpacing(2.8) // 1.2 line spacing (14 * 0.2 = 2.8)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Fallback: try inline-only markdown
                if let inlineString = try? AttributedString(markdown: processedText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(inlineString)
                        .font(.system(size: 14, design: .default))
                        .lineSpacing(2.8) // 1.2 line spacing
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Final fallback to plain text with proper newline handling
                    Text(processedText)
                        .font(.system(size: 14, design: .default))
                        .lineSpacing(2.8) // 1.2 line spacing
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private func processText(_ text: String) -> String {
        var processed = text
        
        // Convert escaped newlines
        processed = processed.replacingOccurrences(of: "\\n", with: "\n")
        
        // Apply spacing fixes (same as MLXResponseParser)
        processed = fixSpacing(processed)
        
        return processed
    }
    
    private func fixSpacing(_ text: String) -> String {
        // Use the same fixSpacing from MLXResponseParser for consistency
        return MLXResponseParser.fixSpacing(text)
    }
}

