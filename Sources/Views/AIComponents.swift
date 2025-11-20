import SwiftUI

// Shared AI components for the unified interface

struct AIResponseCardView: View {
    let card: AIResponseCard
    let onURLClick: (URL) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Minimal Header with Mode Badge
            HStack(alignment: .top) {
                if let mode = card.promptMode {
                    Text(mode.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(modeColor(mode))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(modeColor(mode).opacity(0.15))
                        .cornerRadius(6)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundColor(.blue.opacity(0.6))
                    .font(.system(size: 12))
            }
            
            // AI Response Content - Focus of the card
            Text(card.response)
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(4)
                .textSelection(.enabled)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Relevant URL Section - Subtle
            if let url = card.relevantURL {
                Button(action: {
                    print("🔗 [DEBUG] Clicked URL: \(url.absoluteString)")
                    onURLClick(url)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .font(.system(size: 11))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.host ?? "Link")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                            Text(url.absoluteString)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue.opacity(0.6))
                            .font(.system(size: 14))
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: 600)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private func modeColor(_ mode: PromptMode) -> Color {
        switch mode {
        case .concise:
            return .green
        case .detailed:
            return .blue
        case .creative:
            return .purple
        }
    }
}

