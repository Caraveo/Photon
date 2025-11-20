import SwiftUI

// Notification bubble that can be dismissed - rounded bubble square with beautiful shadow
struct NotificationBubble: View {
    let notification: AINotification
    let onDismiss: () -> Void
    let onURLClick: ((URL) -> Void)?
    
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            HStack(alignment: .top, spacing: 12) {
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Title/Query
                    if let promptMode = notification.promptMode {
                        HStack {
                            Text(promptMode.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Response text
                    Text(notification.response)
                        .font(.system(size: 13))
                        .lineLimit(4)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                    
                    // URL link if available
                    if let url = notification.relevantURL {
                        Button(action: {
                            onURLClick?(url)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 10))
                                Text(url.host ?? "Link")
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Dismiss button
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            .padding(16)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 6)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .transition(.move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
        }
    }
}

// Container view for managing multiple notification bubbles
struct NotificationBubbleStack: View {
    @Binding var notifications: [AINotification]
    let onURLClick: ((URL) -> Void)?
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(notifications) { notification in
                NotificationBubble(
                    notification: notification,
                    onDismiss: {
                        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                            notifications.remove(at: index)
                        }
                    },
                    onURLClick: onURLClick
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

