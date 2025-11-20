import SwiftUI

struct TabBarView: View {
    @ObservedObject var tabManager: TabManager
    @State private var draggedTab: BrowserTab?
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabManager.tabs) { tab in
                        TabView(tab: tab, isActive: tab.id == tabManager.activeTabId) {
                            tabManager.switchToTab(tab)
                        } onClose: {
                            tabManager.closeTab(tab)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // New Tab Button - Only show if there's only one tab
            if tabManager.tabs.count == 1 {
                Button(action: {
                    tabManager.createNewTab()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
        }
        .frame(height: 48)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
}

struct TabView: View {
    @ObservedObject var tab: BrowserTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Tab icon or loading indicator
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isActive ? .blue : .secondary)
                    .frame(width: 16, height: 16)
            }
            
            // Tab title
            Text(tab.title)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)
                .frame(maxWidth: 180)
            
            // Close button
            if isHovered || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 18, height: 18)
                .onHover { hovering in
                    // Add hover effect for close button
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color(NSColor.windowBackgroundColor) : Color.clear)
                .shadow(color: isActive ? Color.black.opacity(0.05) : Color.clear, radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Close Tab") {
                onClose()
            }
        }
    }
}

