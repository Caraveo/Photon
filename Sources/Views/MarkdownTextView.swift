import SwiftUI

// Beautiful markdown rendering view with enhanced formatting for human readability
struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        // Process text to handle newlines and spacing properly
        let processedText = processText(text)
        
        // Parse and render markdown with full syntax support
        if let attributedString = try? AttributedString(markdown: processedText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)) {
            // Beautiful typography with optimal readability
            Text(attributedString)
                .font(.system(size: 15, design: .default)) // Slightly larger for readability
                .lineSpacing(8) // More generous line spacing (1.5x line height)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        } else {
            // Fallback: try inline-only markdown
            if let inlineString = try? AttributedString(markdown: processedText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(inlineString)
                    .font(.system(size: 15, design: .default))
                    .lineSpacing(8) // More generous line spacing
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            } else {
                // Final fallback to plain text with proper newline handling
                Text(processedText)
                    .font(.system(size: 15, design: .default))
                    .lineSpacing(8) // More generous line spacing
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
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

