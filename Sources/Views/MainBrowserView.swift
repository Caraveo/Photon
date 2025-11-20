import SwiftUI
import AppKit

struct MainBrowserView: View {
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var aiService: LocalAIService
    @EnvironmentObject var settings: AISettings
    @StateObject private var tabManager = TabManager()
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var isSearchFieldVisible: Bool = true
    @State private var mouseLocation: NSPoint = .zero
    @State private var lastMouseMoveTime: Date = Date()
    @State private var hideTimer: Timer?
    @State private var isScrolling: Bool = false
    @State private var inactivityTimer: Timer?
    @State private var shouldShowCentered: Bool = true // Show centered on launch/new tab
    
    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding {
                // Show onboarding on first launch
                OnboardingView(settings: settings, aiService: aiService)
            } else {
                mainBrowserContent
            }
        }
    }
    
    private var mainBrowserContent: some View {
        GeometryReader { geometry in
            let tabBarHeight: CGFloat = tabManager.tabs.count > 1 ? 48 : 0
            let browserTopOffset = tabBarHeight
            let browserHeight = geometry.size.height - browserTopOffset
            
            ZStack {
                // Main browser view - positioned below tab bar and AI cards, fills remaining space
                // Show all tabs but only display the active one (prevents reload)
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: browserTopOffset)
                    
                    ZStack {
                        ForEach(tabManager.tabs) { tab in
                            TabBrowserView(tab: tab)
                                .frame(width: geometry.size.width, height: browserHeight)
                                .opacity(tab.id == tabManager.activeTabId ? 1 : 0)
                                .allowsHitTesting(tab.id == tabManager.activeTabId)
                                .zIndex(tab.id == tabManager.activeTabId ? 1 : 0)
                        }
                        
                        if tabManager.tabs.isEmpty {
                            // Placeholder if no tabs
                            Color(NSColor.windowBackgroundColor)
                                .frame(width: geometry.size.width, height: browserHeight)
                        }
                    }
                }
                .onChange(of: tabManager.activeTabId) { newActiveTabId in
                    // Pause inactive tabs and resume active tab
                    for tab in tabManager.tabs {
                        if tab.id == newActiveTabId {
                            tab.resume()
                        } else {
                            tab.pause()
                        }
                    }
                }
                
                // Overlay content on top of browser - only blocks the top portion
                VStack(spacing: 0) {
                    // Tab Bar - Only show when there are 2+ tabs
                    if tabManager.tabs.count > 1 {
                        TabBarView(tabManager: tabManager)
                            .allowsHitTesting(true) // Tab bar should be clickable
                    }
                    
                    
                    // Spacer that allows clicks to pass through to browser
                    Spacer()
                        .allowsHitTesting(false) // Allow clicks to pass through to browser
                }
                
                // Notification Bubbles - Floating overlay in top right corner
                if let activeTab = tabManager.activeTab,
                   (!activeTab.aiNotifications.isEmpty || activeTab.isProcessingAI) {
                    VStack {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 12) {
                                // Notification bubbles
                                ForEach(activeTab.aiNotifications) { notification in
                                    NotificationBubble(
                                        notification: notification,
                                        onDismiss: {
                                            if let index = activeTab.aiNotifications.firstIndex(where: { $0.id == notification.id }) {
                                                activeTab.aiNotifications.remove(at: index)
                                            }
                                        },
                                        onURLClick: { url in
                                            activeTab.navigate(to: url.absoluteString)
                                        }
                                    )
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                                
                                // Processing indicator with thinking messages
                                if activeTab.isProcessingAI {
                                    ThinkingIndicatorView(activeTab: activeTab)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                            }
                            .padding(.top, tabBarHeight + 16)
                            .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                    .allowsHitTesting(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Unified Search/Input Field - Overlay on browser (only in browser area, not over tab bar)
                // Must not block browser interaction
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: browserTopOffset)
                        .allowsHitTesting(false) // Don't block browser
                    
                    ZStack {
                        if !isSearchActive && shouldShowCentered {
                            // Centered search field - only on new tab or launch
                            UnifiedSearchField(
                                text: $searchText,
                                isActive: $isSearchActive,
                                onSearch: handleSearch,
                                onAISearch: handleAISearch,
                                activeTab: tabManager.activeTab
                            )
                            .frame(width: 800)
                            .environmentObject(settings)
                            .opacity(isSearchFieldVisible ? 1 : 0)
                            .scaleEffect(isSearchFieldVisible ? 1 : 0.95)
                            .transition(.scale.combined(with: .opacity))
                            .allowsHitTesting(isSearchFieldVisible) // Only block when visible
                            .onChange(of: isSearchActive) { active in
                                // Switch from centered to positioned mode when user activates search
                                if active {
                                    shouldShowCentered = false
                                }
                            }
                        } else {
                            // Positioned search field (TOP or BOTTOM based on settings) - when active or after first interaction
                            VStack {
                                if settings.searchFieldPosition == .bottom {
                                    Spacer()
                                }
                                
                                UnifiedSearchField(
                                    text: $searchText,
                                    isActive: $isSearchActive,
                                    onSearch: handleSearch,
                                    onAISearch: handleAISearch,
                                    activeTab: tabManager.activeTab
                                )
                                .padding(.horizontal, 40)
                                .padding(settings.searchFieldPosition == .top ? .top : .bottom, 40)
                                .environmentObject(settings)
                                .opacity(isSearchActive || isSearchFieldVisible ? 1 : 0)
                                .transition(.move(edge: settings.searchFieldPosition == .top ? .top : .bottom).combined(with: .opacity))
                                
                                if settings.searchFieldPosition == .top {
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: browserHeight)
                    .allowsHitTesting(isSearchActive || isSearchFieldVisible) // Only block when search is active or visible
                    .onChange(of: isSearchActive) { active in
                        // Switch from centered to positioned mode when user activates search
                        if active {
                            shouldShowCentered = false
                        }
                    }
                    .onHover { hovering in
                        if let window = NSApplication.shared.windows.first {
                            let windowLocation = NSEvent.mouseLocation
                            let windowFrame = window.frame
                            let mouseY = windowLocation.y - windowFrame.minY
                            handleMouseHover(hovering: hovering, mouseY: mouseY, browserHeight: browserHeight, topOffset: browserTopOffset)
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSearchActive)
                .animation(.easeInOut(duration: 0.25), value: isSearchFieldVisible)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            // Don't auto-connect - user must connect manually
            
            // Start monitoring mouse movement and scrolling
            startMouseMonitoring()
        }
        .onDisappear {
            stopMouseMonitoring()
            hideTimer?.invalidate()
            inactivityTimer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewTab"))) { _ in
            tabManager.createNewTab()
            // Show centered on new tab
            shouldShowCentered = true
        }
        .background(
            // Handle CMD+T (or CTRL+T) keyboard shortcut
            Button("New Tab") {
                tabManager.createNewTab()
                // Show centered on new tab
                shouldShowCentered = true
            }
            .keyboardShortcut("t", modifiers: [.command])
            .hidden()
        )
        .onAppear {
            // Also handle CTRL+T for Windows/Linux compatibility
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if (event.modifierFlags.contains(.control) || event.modifierFlags.contains(.command)) 
                    && event.charactersIgnoringModifiers?.lowercased() == "t" {
                    tabManager.createNewTab()
                    // Show centered on new tab
                    shouldShowCentered = true
                    return nil
                }
                return event
            }
        }
    }
    
    private func handleSearch() {
        guard !searchText.isEmpty else { return }
        
        let query = searchText
        searchText = ""
        
        // Reset search field to centered after search and hide it
        withAnimation {
            isSearchActive = false
            isSearchFieldVisible = false
        }
        
        // Determine if it's a URL or search query
        guard let activeTab = tabManager.activeTab else { return }
        
        if query.hasPrefix("http://") || query.hasPrefix("https://") {
            activeTab.navigate(to: query)
        } else if query.contains(".") && !query.contains(" ") {
            // Likely a domain
            activeTab.navigate(to: "https://\(query)")
        } else {
            // Use selected search engine
            switch settings.selectedSearchEngine {
            case .duckduckgo, .google:
                let searchURL = settings.selectedSearchEngine.buildSearchURL(query: query)
                activeTab.navigate(to: searchURL)
            case .photon:
                // Use Photon Search Realtime
                handlePhotonSearch(query: query)
            }
        }
    }
    
    private func handlePhotonSearch(query: String) {
        guard let activeTab = tabManager.activeTab else { return }
        
        // Show loading state
        activeTab.isProcessingAI = true
        activeTab.aiNotifications.removeAll()
        
        Task {
            do {
                let photonSearch = PhotonSearchService(aiService: aiService)
                let result = try await photonSearch.search(query: query)
                
                await MainActor.run {
                    // Create AI notification
                    let notification = AINotification(
                        response: result.aiResponse,
                        relevantURL: result.relevantURLs.first?.absoluteString,
                        query: query,
                        promptMode: nil
                    )
                    activeTab.aiNotifications.append(notification)
                    activeTab.isProcessingAI = false
                    
                    // Navigate to first relevant URL if available
                    if let firstURL = result.relevantURLs.first {
                        activeTab.navigate(to: firstURL.absoluteString)
                    }
                }
            } catch {
                await MainActor.run {
                    let errorNotification = AINotification(
                        response: "Error performing Photon Search: \(error.localizedDescription)",
                        relevantURL: nil,
                        query: query,
                        promptMode: nil
                    )
                    activeTab.aiNotifications.append(errorNotification)
                    activeTab.isProcessingAI = false
                }
            }
        }
    }
    
    private func generateAndRunMultiplePrompts(for query: String) {
        guard let activeTab = tabManager.activeTab else { return }
        
        activeTab.isProcessingAI = true
        
        // Clear previous notifications for this search
        activeTab.aiNotifications.removeAll()
        
        // Only proceed if already connected - no auto-connect
        if !aiService.isConnected {
            activeTab.isProcessingAI = false
            let errorNotification = AINotification(
                response: "AI service not connected. Please connect in Settings (File → Settings) or click the Connect button.",
                relevantURL: nil,
                query: query,
                promptMode: nil
            )
            activeTab.aiNotifications.insert(errorNotification, at: 0)
            return
        }
        
        Task {
            await generatePromptsAfterConnection(query: query, activeTab: activeTab)
        }
    }
    
    private func generatePromptsAfterConnection(query: String, activeTab: BrowserTab) async {
        // Generate single prompt with markdown formatting request
        let selectedModel = settings.selectedModel
        let prompt = """
        Please provide a comprehensive answer to the following question using Markdown formatting.
        Use **bold** for emphasis, *italic* for subtle emphasis, `code` for technical terms, 
        and proper line breaks for readability. Format lists with - or 1. and use ## for headings if needed.
        
        Question: \(query)
        
        Answer (in Markdown):
        """
        
        do {
            let response = try await aiService.sendMessage(prompt, model: selectedModel)
            
            // Parse MLX response to extract reasoning if present
            let parsed = MLXResponseParser.parse(response.response)
            
            await MainActor.run {
                // Show reasoning in thinking indicator if available
                if !parsed.reasoning.isEmpty {
                    activeTab.currentReasoning = parsed.reasoning
                }
                
                // Use answer section or full response, and apply spacing fixes
                var answer = parsed.answer.isEmpty ? response.response : parsed.answer
                answer = MLXResponseParser.fixSpacing(answer)
                
                let notification = AINotification(
                    response: answer,
                    relevantURL: response.relevantURL,
                    query: query,
                    promptMode: nil
                )
                activeTab.aiNotifications.insert(notification, at: 0)
                activeTab.isProcessingAI = false
                activeTab.currentReasoning = "" // Clear reasoning after showing notification
            }
        } catch {
            await MainActor.run {
                let errorMessage: String
                if let aiError = error as? AIError {
                    errorMessage = aiError.localizedDescription
                } else {
                    errorMessage = "Error: \(error.localizedDescription)"
                }
                let errorNotification = AINotification(
                    response: errorMessage,
                    relevantURL: nil,
                    query: query,
                    promptMode: nil
                )
                activeTab.aiNotifications.insert(errorNotification, at: 0)
                activeTab.isProcessingAI = false
            }
        }
    }
    
    private func handleAISearch() {
        guard !searchText.isEmpty else { return }
        let query = searchText
        searchText = ""
        
        // Reset search field to centered after AI search and hide it
        withAnimation {
            isSearchActive = false
            isSearchFieldVisible = false
        }
        
        // Use the same multi-prompt system for AI search
        generateAndRunMultiplePrompts(for: query)
    }
    
    // MARK: - Mouse Movement & Scrolling Detection
    
    @State private var mouseMonitor: Any?
    @State private var scrollMonitor: Any?
    @State private var localMouseMonitor: Any?
    @State private var localScrollMonitor: Any?
    @State private var keyMonitor: Any?
    @State private var lastScrollTime: Date = Date()
    @State private var scrollVelocity: CGFloat = 0
    
    private func startMouseMonitoring() {
        // Monitor mouse movement globally
        let globalMouse = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { event in
            DispatchQueue.main.async {
                self.handleMouseEvent(event)
            }
        }
        mouseMonitor = globalMouse
        
        // Monitor local mouse events (when window is active)
        let localMouse = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown]) { event in
            DispatchQueue.main.async {
                if event.type == .leftMouseDown || event.type == .rightMouseDown {
                    self.handleMouseClick(event)
                } else {
                    self.handleMouseEvent(event)
                }
            }
            return event
        }
        localMouseMonitor = localMouse
        
        // Monitor scrolling globally
        let globalScroll = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { event in
            DispatchQueue.main.async {
                self.handleScrollEvent(event)
            }
        }
        scrollMonitor = globalScroll
        
        // Monitor scrolling locally
        let localScroll = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { event in
            DispatchQueue.main.async {
                self.handleScrollEvent(event)
            }
            return event
        }
        localScrollMonitor = localScroll
        
        // Monitor keyboard events
        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            DispatchQueue.main.async {
                self.handleKeyEvent(event)
            }
            return event
        }
        self.keyMonitor = keyMonitor
        
        // Start with search field visible
        isSearchFieldVisible = true
        
        // Start inactivity timer to hide search field after no interaction
        startInactivityTimer()
    }
    
    private func stopMouseMonitoring() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let monitor = localScrollMonitor {
            NSEvent.removeMonitor(monitor)
            localScrollMonitor = nil
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        guard let window = NSApplication.shared.windows.first else { return }
        
        let windowLocation = event.locationInWindow
        let screenLocation = window.convertPoint(toScreen: windowLocation)
        mouseLocation = screenLocation
        lastMouseMoveTime = Date()
        
        // Show search field on any mouse movement (user is active)
        showSearchFieldOnActivity()
    }
    
    private func handleMouseClick(_ event: NSEvent) {
        // Show search field on click (user is active)
        showSearchFieldOnActivity()
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Show search field on any keypress (user is active)
        showSearchFieldOnActivity()
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        // Calculate scroll velocity to detect fast scrolling
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastScrollTime)
        lastScrollTime = now
        
        // Get scroll delta (magnitude of scroll)
        let scrollDelta = abs(event.scrollingDeltaY) + abs(event.scrollingDeltaX)
        
        // Calculate velocity (pixels per second)
        if timeDelta > 0 {
            scrollVelocity = scrollDelta / CGFloat(timeDelta)
        } else {
            scrollVelocity = scrollDelta
        }
        
        // Fast scroll threshold: > 500 pixels per second
        let fastScrollThreshold: CGFloat = 500.0
        
        if scrollVelocity > fastScrollThreshold {
            // Fast scrolling - hide search field
            isScrolling = true
            updateSearchFieldVisibility(shouldShow: false)
        } else {
            // Slow/regular scrolling - show search field (user is active)
            isScrolling = false
            showSearchFieldOnActivity()
        }
        
        // Decay scroll velocity over time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.scrollVelocity *= 0.5
            if self.scrollVelocity < 50 {
                self.isScrolling = false
            }
        }
    }
    
    private func showSearchFieldOnActivity() {
        // Show search field immediately on any user activity
        isSearchFieldVisible = true
        resetInactivityTimer()
    }
    
    private func handleMouseHover(hovering: Bool, mouseY: CGFloat, browserHeight: CGFloat, topOffset: CGFloat) {
        if hovering {
            // Show search field on hover (user is active)
            showSearchFieldOnActivity()
        }
    }
    
    private func updateSearchFieldVisibility(shouldShow: Bool) {
        // Don't hide if search is active (user is typing)
        if isSearchActive {
            isSearchFieldVisible = true
            resetInactivityTimer()
            return
        }
        
        // Cancel existing hide timer
        hideTimer?.invalidate()
        
        if shouldShow {
            // Show immediately
            isSearchFieldVisible = true
            resetInactivityTimer()
        } else {
            // Only hide if fast scrolling or idle (handled by inactivity timer)
            // Don't hide on regular activity
        }
    }
    
    private func startInactivityTimer() {
        // Hide search field after 5 seconds of inactivity
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            DispatchQueue.main.async {
                // Only hide if not active, not fast scrolling, and truly idle
                if !self.isSearchActive && !self.isScrolling {
                    self.isSearchFieldVisible = false
                }
            }
        }
    }
    
    private func resetInactivityTimer() {
        // Cancel existing timer
        inactivityTimer?.invalidate()
        
        // Restart timer if search field is visible
        if isSearchFieldVisible && !isSearchActive {
            startInactivityTimer()
        }
    }
}

struct UnifiedSearchField: View {
    @Binding var text: String
    @Binding var isActive: Bool
    @EnvironmentObject var aiService: LocalAIService
    @EnvironmentObject var settings: AISettings
    let onSearch: () -> Void
    let onAISearch: () -> Void
    let activeTab: BrowserTab?
    @FocusState private var isFocused: Bool
    @State private var showModelPicker: Bool = false
    @State private var showAPIKeyDialog: Bool = false
    @State private var tempAPIKey: String = ""
    
    var body: some View {
        HStack(spacing: 8) {
            // Navigation controls: Back, Forward, Refresh
            HStack(spacing: 4) {
                // Back button
                Button(action: {
                    activeTab?.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(activeTab?.canGoBack == true ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(activeTab?.canGoBack != true)
                
                // Forward button
                Button(action: {
                    activeTab?.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(activeTab?.canGoForward == true ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(activeTab?.canGoForward != true)
                
                // Refresh button
                Button(action: {
                    activeTab?.reload()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 4)
            
            // Discreet Model Selector Dropdown - only show if not hidden in settings
            if !settings.hideAIServiceInSearch {
                ModelSelectorDropdown(
                    selectedModel: $settings.selectedModel,
                    availableModels: aiService.availableModels.filter { $0.provider == settings.selectedProvider },
                    selectedProvider: $settings.selectedProvider,
                    settings: settings,
                    onProviderChange: { newProvider in
                        settings.setProvider(newProvider)
                        // Don't auto-connect - user must connect manually
                    },
                    onAPIKeyNeeded: {
                        showAPIKeyDialog = true
                    }
                )
                .frame(width: 140)
            }
            
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField("Search or ask AI...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($isFocused)
                .onSubmit {
                    onSearch()
                }
                .onTapGesture {
                    // Only activate when user clicks, not on focus
                    if !isActive {
                        withAnimation {
                            isActive = true
                        }
                    }
                }
                .onChange(of: isFocused) { focused in
                    // Move to positioned mode when focused/typing
                    if focused && !isActive {
                        withAnimation {
                            isActive = true
                        }
                    }
                }
            
            if !text.isEmpty {
                Button(action: onAISearch) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .sheet(isPresented: $showAPIKeyDialog) {
            APIKeyDialog(
                provider: settings.selectedProvider,
                apiKey: $tempAPIKey,
                onSave: {
                    if settings.selectedProvider == .openai {
                        settings.saveOpenAIKey(tempAPIKey)
                    } else if settings.selectedProvider == .mistral {
                        settings.saveMistralKey(tempAPIKey)
                    }
                    tempAPIKey = ""
                    // User can connect manually after saving key
                },
                onCancel: {
                    tempAPIKey = ""
                }
            )
        }
    }
}

struct ModelSelectorDropdown: View {
    @Binding var selectedModel: AIModel
    let availableModels: [AIModel]
    @Binding var selectedProvider: AIProvider
    let settings: AISettings
    let onProviderChange: (AIProvider) -> Void
    let onAPIKeyNeeded: () -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        Menu {
            // Provider selection
            Picker("Provider", selection: $selectedProvider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .onChange(of: selectedProvider) { newProvider in
                onProviderChange(newProvider)
                // Only prompt for API key for cloud providers (not local ones like MLX or Ollama)
                let needsKey = (newProvider == .openai && settings.openAIKey.isEmpty) ||
                              (newProvider == .mistral && settings.mistralKey.isEmpty)
                if needsKey {
                    onAPIKeyNeeded()
                }
            }
            
            Divider()
            
            // Model selection
            ForEach(availableModels.filter { $0.provider == selectedProvider }) { model in
                Button(action: {
                    selectedModel = model
                }) {
                    HStack {
                        Text(model.name)
                        if model.id == selectedModel.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(selectedModel.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }
}

struct APIKeyDialog: View {
    let provider: AIProvider
    @Binding var apiKey: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var tempKey: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter \(provider.rawValue) API Key")
                .font(.headline)
            
            SecureField("API Key", text: $tempKey)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .onAppear {
                    tempKey = apiKey
                }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    apiKey = tempKey
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(tempKey.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}

