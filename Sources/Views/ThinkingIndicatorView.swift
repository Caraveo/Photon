import SwiftUI

// Animated thinking indicator with rotating messages and reasoning display
struct ThinkingIndicatorView: View {
    let activeTab: BrowserTab?
    @State private var currentMessageIndex = 0
    @State private var messageTimer: Timer?
    @State private var animatedRotation: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show reasoning if available, otherwise show rotating thinking messages
            if let tab = activeTab, !tab.currentReasoning.isEmpty {
                // Real-time reasoning display
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                            .foregroundColor(.blue.opacity(0.7))
                            .rotationEffect(.degrees(animatedRotation))
                            .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: animatedRotation)
                        
                        Text("Reasoning")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(tab.currentReasoning)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
            } else {
                // Thinking message - randomized
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundColor(.blue.opacity(0.7))
                        .rotationEffect(.degrees(animatedRotation))
                        .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: animatedRotation)
                    
                    Text(ThinkingMessages.at(index: currentMessageIndex))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .id(currentMessageIndex) // Force view update on change
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .onAppear {
            startMessageRotation()
        }
        .onDisappear {
            stopMessageRotation()
        }
    }
    
    private func startMessageRotation() {
        // Start brain icon rotation animation
        animatedRotation = 360
        
        // Start with a random message
        currentMessageIndex = Int.random(in: 0..<ThinkingMessages.messages.count)
        
        // Rotate through messages randomly every 1.5 seconds
        messageTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                // Randomly select next message (not just sequential)
                var nextIndex: Int
                repeat {
                    nextIndex = Int.random(in: 0..<ThinkingMessages.messages.count)
                } while nextIndex == currentMessageIndex && ThinkingMessages.messages.count > 1
                currentMessageIndex = nextIndex
            }
        }
    }
    
    private func stopMessageRotation() {
        messageTimer?.invalidate()
        messageTimer = nil
    }
}

