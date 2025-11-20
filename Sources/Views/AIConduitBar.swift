import SwiftUI

struct AIConduitBar: View {
    @EnvironmentObject var aiService: LocalAIService
    @EnvironmentObject var browserState: BrowserState
    @State private var userInput: String = ""
    @State private var userQueries: [String] = []
    @State private var aiResponseCards: [AIResponseCard] = []
    @State private var isProcessing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("Mistral AI")
                    .font(.headline)
                Spacer()
                if aiService.isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Cards Area
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // Show user queries
                    ForEach(Array(userQueries.enumerated()), id: \.offset) { index, query in
                        UserQueryBubble(query: query)
                    }
                    
                    // Show AI response cards
                    ForEach(aiResponseCards) { card in
                        AIResponseCardView(card: card) { url in
                            // Navigate to URL in browser
                            browserState.navigate(to: url.absoluteString)
                        }
                    }
                    
                    if isProcessing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Input Area
            VStack(spacing: 8) {
                HStack {
                    TextField("Ask Mistral AI...", text: $userInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .disabled(isProcessing || !aiService.isConnected)
                    
                    Button(action: sendMessage) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(userInput.isEmpty || isProcessing || !aiService.isConnected)
                }
                
                if !aiService.isConnected {
                    Button("Connect to Local Mistral AI") {
                        aiService.connect()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func sendMessage() {
        guard !userInput.isEmpty, !isProcessing else { return }
        
        let query = userInput
        userQueries.append(query)
        userInput = ""
        isProcessing = true
        
        Task {
            do {
                let response = try await aiService.sendMessage(query)
                await MainActor.run {
                    let card = AIResponseCard(
                        response: response.response,
                        relevantURL: response.relevantURL,
                        query: response.query
                    )
                    aiResponseCards.append(card)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    // Create error card
                    let errorCard = AIResponseCard(
                        response: "Error: \(error.localizedDescription)",
                        relevantURL: nil,
                        query: query
                    )
                    aiResponseCards.append(errorCard)
                    isProcessing = false
                }
            }
        }
    }
}

struct UserQueryBubble: View {
    let query: String
    
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(query)
                    .padding(10)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(12)
            }
            .frame(maxWidth: 280, alignment: .trailing)
        }
    }
}

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

