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
                    .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
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
            .clipped() // Prevent content from overflowing bubble bounds
        }
    }
    
    // Collapsed compact view
    private var collapsedView: some View {
        HStack(alignment: .top, spacing: 12) {
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Query as Title
                Text(notification.query)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                
                // Response text with markdown rendering (apply spacing fixes first)
                let processedResponse = MLXResponseParser.fixSpacing(notification.response)
                if let attributedString = try? AttributedString(markdown: processedResponse, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributedString)
                        .font(.system(size: 14, design: .default)) // Better readability
                        .lineSpacing(6) // Generous line spacing
                        .lineLimit(4)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(processedResponse)
                        .font(.system(size: 14, design: .default))
                        .lineSpacing(6)
                        .lineLimit(4)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                
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
        .fixedSize(horizontal: true, vertical: false)
    }
    
    // Expanded full mode view
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with query as title and close buttons
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // Query as formatted title
                    Text(notification.query)
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .lineSpacing(4)
                    
                    if let promptMode = notification.promptMode {
                        Text(promptMode.rawValue)
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
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
                .padding(.vertical, 6)
            
            // Full response text with markdown rendering - beautifully formatted
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // Render markdown with beautiful formatting
                    MarkdownTextView(text: notification.response)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 8) // Padding for scrollbar
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4) // Vertical padding for breathing room
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
        .fixedSize(horizontal: true, vertical: false)
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

