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
        GeometryReader { geometry in
            let tabBarHeight: CGFloat = tabManager.tabs.count > 1 ? 48 : 0
            let aiCardsHeight: CGFloat = {
                if let activeTab = tabManager.activeTab,
                   (!activeTab.aiResponseCards.isEmpty || activeTab.isProcessingAI) {
                    return 280
                }
                return 0
            }()
            let browserTopOffset = tabBarHeight + aiCardsHeight
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
                    
                    // AI Response Cards - Horizontal row below tab bar (for active tab)
                    if let activeTab = tabManager.activeTab,
                       (!activeTab.aiResponseCards.isEmpty || activeTab.isProcessingAI) {
                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                // Close button - make sure it's clickable
                                Button(action: {
                                    withAnimation {
                                        activeTab.aiResponseCards.removeAll()
                                        activeTab.isProcessingAI = false
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.title3)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 20)
                                .contentShape(Rectangle())
                                .allowsHitTesting(true)
                                
                                // Horizontal scrollable cards
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(activeTab.aiResponseCards) { card in
                                            AIResponseCardView(card: card) { url in
                                                activeTab.navigate(to: url.absoluteString)
                                            }
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                        
                                        if activeTab.isProcessingAI {
                                            HStack(spacing: 12) {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                Text("Generating...")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(20)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(NSColor.controlBackgroundColor))
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 20)
                                }
                            }
                            .frame(height: 280)
                            .background(
                                Color(NSColor.windowBackgroundColor)
                                    .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                            )
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(true) // Ensure cards area is clickable
                    }
                    
                    // Spacer that allows clicks to pass through to browser
                    Spacer()
                        .allowsHitTesting(false) // Allow clicks to pass through to browser
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
            // Initialize AI service with settings
            aiService.settings = settings
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
            // Search query - use Google search (no automatic AI)
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            activeTab.navigate(to: "https://www.google.com/search?q=\(encodedQuery)")
        }
    }
    
    private func generateAndRunMultiplePrompts(for query: String) {
        guard let activeTab = tabManager.activeTab else { return }
        
        activeTab.isProcessingAI = true
        
        // Clear previous cards for this search
        activeTab.aiResponseCards.removeAll()
        
        // Only proceed if already connected - no auto-connect
        if !aiService.isConnected {
            activeTab.isProcessingAI = false
            let errorCard = AIResponseCard(
                response: "AI service not connected. Please connect in Settings (File → Settings) or click the Connect button.",
                relevantURL: nil,
                query: query,
                promptMode: nil
            )
            activeTab.aiResponseCards.insert(errorCard, at: 0)
            return
        }
        
        Task {
            await generatePromptsAfterConnection(query: query, activeTab: activeTab)
        }
    }
    
    private func generatePromptsAfterConnection(query: String, activeTab: BrowserTab) async {
        // Generate 3 different prompts
        let prompts = PromptGenerator.generatePrompts(from: query)
        let selectedModel = settings.selectedModel
        var completedCount = 0
        let totalPrompts = prompts.count
        
        // Run all 3 prompts in parallel
        await withTaskGroup(of: (PromptMode, Result<AIResponse, Error>).self) { group in
            for (mode, prompt) in prompts {
                    group.addTask {
                        do {
                            let response = try await aiService.sendMessage(prompt, model: selectedModel)
                            return (mode, .success(response))
                        } catch {
                            return (mode, .failure(error))
                    }
                }
            }
            
            // Collect results as they complete
            for await (mode, result) in group {
                await MainActor.run {
                    completedCount += 1
                    
                    switch result {
                    case .success(let response):
                        let card = AIResponseCard(
                            response: response.response,
                            relevantURL: response.relevantURL,
                            query: query,
                            promptMode: mode
                        )
                            activeTab.aiResponseCards.insert(card, at: 0) // Insert at top
                            
                        case .failure(let error):
                            let errorCard = AIResponseCard(
                            response: "Error: \(error.localizedDescription)",
                            relevantURL: nil,
                            query: query,
                            promptMode: mode
                        )
                        activeTab.aiResponseCards.insert(errorCard, at: 0)
                    }
                    
                        // Check if all requests are done
                        if completedCount >= totalPrompts {
                            activeTab.isProcessingAI = false
                        }
                }
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
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        guard let window = NSApplication.shared.windows.first else { return }
        
        let windowLocation = event.locationInWindow
        let screenLocation = window.convertPoint(toScreen: windowLocation)
        mouseLocation = screenLocation
        lastMouseMoveTime = Date()
        
        // Reset inactivity timer on mouse movement
        resetInactivityTimer()
        
        // Get window frame
        let windowFrame = window.frame
        let mouseY = screenLocation.y - windowFrame.minY
        let windowHeight = windowFrame.height
        
        // Show search field if mouse is in top 20% of window
        let topThreshold = windowHeight * 0.20
        let shouldShow = mouseY > (windowHeight - topThreshold)
        
        updateSearchFieldVisibility(shouldShow: shouldShow)
    }
    
    private func handleMouseClick(_ event: NSEvent) {
        guard let window = NSApplication.shared.windows.first else { return }
        
        let windowLocation = event.locationInWindow
        let screenLocation = window.convertPoint(toScreen: windowLocation)
        
        // Get window frame
        let windowFrame = window.frame
        let mouseY = screenLocation.y - windowFrame.minY
        let windowHeight = windowFrame.height
        
        // Calculate if click is in browser area (below tab bar and AI cards)
        let tabBarHeight: CGFloat = tabManager.tabs.count > 1 ? 48 : 0
        let aiCardsHeight: CGFloat = {
            if let activeTab = tabManager.activeTab,
               (!activeTab.aiResponseCards.isEmpty || activeTab.isProcessingAI) {
                return 280
            }
            return 0
        }()
        let browserTopOffset = tabBarHeight + aiCardsHeight
        let browserStartY = windowHeight - browserTopOffset
        
        // If click is in browser area (not in search field or cards), hide search field
        if mouseY < browserStartY && !isSearchActive {
            updateSearchFieldVisibility(shouldShow: false)
        }
        
        // Reset inactivity timer on click
        resetInactivityTimer()
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        // User is scrolling - hide search field immediately
        isScrolling = true
        updateSearchFieldVisibility(shouldShow: false)
        
        // Reset inactivity timer on scroll
        resetInactivityTimer()
        
        // Reset scrolling flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isScrolling = false
            // Check if mouse is in top area to show search field again
            if self.mouseLocation.y > 0 {
                let window = NSApplication.shared.windows.first
                if let window = window {
                    let windowHeight = window.frame.height
                    let mouseY = self.mouseLocation.y - window.frame.minY
                    let topThreshold = windowHeight * 0.20
                    if mouseY > (windowHeight - topThreshold) {
                        self.updateSearchFieldVisibility(shouldShow: true)
                    }
                }
            }
        }
    }
    
    private func handleMouseHover(hovering: Bool, mouseY: CGFloat, browserHeight: CGFloat, topOffset: CGFloat) {
        if hovering {
            // Mouse is hovering over the browser area
            let relativeY = mouseY - topOffset
            let topThreshold = browserHeight * 0.20
            
            // Show if mouse is in top 20% of browser area
            if relativeY < topThreshold {
                updateSearchFieldVisibility(shouldShow: true)
                resetInactivityTimer()
            } else if !isScrolling {
                // Hide if mouse is lower and not scrolling
                updateSearchFieldVisibility(shouldShow: false)
            }
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
            // Hide after a short delay (feels more natural)
            hideTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                DispatchQueue.main.async {
                    // Only hide if still not active and not scrolling
                    if !self.isSearchActive && !self.isScrolling {
                        self.isSearchFieldVisible = false
                    }
                }
            }
        }
    }
    
    private func startInactivityTimer() {
        // Hide search field after 3 seconds of inactivity
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
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

