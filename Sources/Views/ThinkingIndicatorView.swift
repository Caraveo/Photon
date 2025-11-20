import SwiftUI

// Animated thinking indicator with rotating messages
struct ThinkingIndicatorView: View {
    @State private var currentMessageIndex = 0
    @State private var messageTimer: Timer?
    @State private var animatedRotation: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Generating header
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Generating...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            // Thinking message
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
        
        // Rotate through messages every 1.5 seconds
        messageTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMessageIndex = (currentMessageIndex + 1) % ThinkingMessages.messages.count
            }
        }
    }
    
    private func stopMessageRotation() {
        messageTimer?.invalidate()
        messageTimer = nil
    }
}

