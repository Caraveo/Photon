import SwiftUI

struct TabBarView: View {
    @ObservedObject var tabManager: TabManager
    @State private var draggedTab: BrowserTab?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    TabView(tab: tab, isActive: tab.id == tabManager.activeTabId) {
                        tabManager.switchToTab(tab)
                    } onClose: {
                        tabManager.closeTab(tab)
                    }
                }
                
                // New Tab Button
                Button(action: {
                    tabManager.createNewTab()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 32)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
        .frame(height: 36)
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
        HStack(spacing: 6) {
            // Tab icon or loading indicator
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: 12)
            }
            
            // Tab title
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)
                .frame(maxWidth: 150)
            
            // Close button
            if isHovered || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color(NSColor.windowBackgroundColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
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

