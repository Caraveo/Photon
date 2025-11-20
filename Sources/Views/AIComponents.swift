import SwiftUI

// Shared AI components for the unified interface

struct AIResponseCardView: View {
    let card: AIResponseCard
    let onURLClick: (URL) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI Response Content - Focus of the card
            ScrollView(.vertical, showsIndicators: false) {
                // Transparent scrollbar
                Text(card.response)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 180)
            
            // Relevant URL Section - Subtle at bottom
            if let url = card.relevantURL {
                Button(action: {
                    onURLClick(url)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .font(.system(size: 10))
                        Text(url.host ?? "Link")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue.opacity(0.6))
                            .font(.system(size: 12))
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 320, height: 240)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }
}

