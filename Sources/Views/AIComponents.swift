import SwiftUI

// Shared AI components for the unified interface

struct AIResponseCardView: View {
    let card: AIResponseCard
    let onURLClick: (URL) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("AI Response")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(card.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // AI Response Content
            Text(card.response)
                .font(.body)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            
            // Relevant URL Section
            if let url = card.relevantURL {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Relevant Link")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        print("🔗 [DEBUG] Clicked URL: \(url.absoluteString)")
                        onURLClick(url)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.host ?? "Link")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

