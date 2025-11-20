import SwiftUI

struct AIConduitBar: View {
    @EnvironmentObject var aiService: LocalAIService
    @EnvironmentObject var browserState: BrowserState
    @State private var userInput: String = ""
    @State private var userQueries: [String] = []
    @State private var aiNotifications: [AINotification] = []
    @State private var isProcessing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("MLX AI")
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
                    
                    // Show AI notification bubbles
                    ForEach(aiNotifications) { notification in
                        NotificationBubble(
                            notification: notification,
                            onDismiss: {
                                if let index = aiNotifications.firstIndex(where: { $0.id == notification.id }) {
                                    aiNotifications.remove(at: index)
                                }
                            },
                            onURLClick: { url in
                                browserState.navigate(to: url.absoluteString)
                            }
                        )
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
                    TextField("Ask MLX AI...", text: $userInput, axis: .vertical)
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
                    Button("Connect to MLX") {
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
                    let notification = AINotification(
                        response: response.response,
                        relevantURL: response.relevantURL,
                        query: response.query
                    )
                    aiNotifications.append(notification)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    // Create error notification
                    let errorNotification = AINotification(
                        response: "Error: \(error.localizedDescription)",
                        relevantURL: nil,
                        query: query
                    )
                    aiNotifications.append(errorNotification)
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


