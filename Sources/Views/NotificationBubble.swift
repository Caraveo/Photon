import SwiftUI

// Notification bubble that can be dismissed and expanded - rounded bubble square with beautiful shadow
struct NotificationBubble: View {
    let notification: AINotification
    let onDismiss: () -> Void
    let onURLClick: ((URL) -> Void)?
    
    @State private var isVisible = true
    @State private var isExpanded = false
    
    var body: some View {
        if isVisible {
            Group {
                if isExpanded {
                    // Expanded full mode
                    expandedView
                } else {
                    // Collapsed compact mode
                    collapsedView
                }
            }
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
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            .contentShape(Rectangle())
            .onTapGesture {
                // Make entire bubble clickable to expand (when collapsed)
                if !isExpanded {
                    withAnimation {
                        isExpanded = true
                    }
                }
            }
        }
    }
    
    // Collapsed compact view
    private var collapsedView: some View {
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
    }
    
    // Expanded full mode view
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and close button
            HStack {
                if let promptMode = notification.promptMode {
                    Text(promptMode.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    withAnimation {
                        isExpanded = false
                    }
                }) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Collapse")
                
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            
            Divider()
            
            // Full response text
            ScrollView(.vertical, showsIndicators: true) {
                Text(notification.response)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 400)
            
            // URL link if available
            if let url = notification.relevantURL {
                Divider()
                Button(action: {
                    onURLClick?(url)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open Link")
                                .font(.system(size: 13, weight: .semibold))
                            Text(url.absoluteString)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.blue)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 600)
        .frame(maxHeight: 500)
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

