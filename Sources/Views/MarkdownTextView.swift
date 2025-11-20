import SwiftUI

// Beautiful markdown rendering view with enhanced formatting
struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Parse and render markdown with full syntax support
            if let attributedString = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)) {
                // Apply custom styling to the markdown
                Text(attributedString)
                    .font(.system(size: 14, design: .default))
                    .lineSpacing(8)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Fallback: try inline-only markdown
                if let inlineString = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(inlineString)
                        .font(.system(size: 14, design: .default))
                        .lineSpacing(8)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Final fallback to plain text
                    Text(text)
                        .font(.system(size: 14, design: .default))
                        .lineSpacing(8)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

