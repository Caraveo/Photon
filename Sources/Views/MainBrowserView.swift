import SwiftUI
import AppKit

struct MainBrowserView: View {
    init() {
        print("🚀 [DEBUG] MainBrowserView initialized")
    }
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
                    }
                    
                    // AI Response Cards - Horizontal row below tab bar (for active tab)
                    if let activeTab = tabManager.activeTab,
                       (!activeTab.aiResponseCards.isEmpty || activeTab.isProcessingAI) {
                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                // Close button - make sure it's clickable
                                Button(action: {
                                    print("🔴 [DEBUG] Close button clicked")
                                    withAnimation {
                                        activeTab.aiResponseCards.removeAll()
                                        activeTab.isProcessingAI = false
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 20)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    print("🔴 [DEBUG] Close button tapped")
                                    withAnimation {
                                        activeTab.aiResponseCards.removeAll()
                                        activeTab.isProcessingAI = false
                                    }
                                }
                                
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
                        .frame(height: browserHeight)
                        .allowsHitTesting(false) // Allow clicks to pass through to browser
                }
                .allowsHitTesting(true) // But the top portion (cards) should be clickable
                
                // Unified Search/Input Field - Overlay on browser (only in browser area, not over tab bar)
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: browserTopOffset)
                    
                    ZStack {
                        if !isSearchActive {
                            // Centered search field - properly centered in browser area
                            UnifiedSearchField(
                                text: $searchText,
                                isActive: $isSearchActive,
                                onSearch: handleSearch,
                                onAISearch: handleAISearch
                            )
                            .frame(width: 700)
                            .environmentObject(settings)
                            .opacity(isSearchFieldVisible ? 1 : 0)
                            .scaleEffect(isSearchFieldVisible ? 1 : 0.95)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Bottom search field when active
                            VStack {
                                Spacer()
                                UnifiedSearchField(
                                    text: $searchText,
                                    isActive: $isSearchActive,
                                    onSearch: handleSearch,
                                    onAISearch: handleAISearch
                                )
                                .padding(.horizontal, 40)
                                .padding(.bottom, 40)
                                .environmentObject(settings)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: browserHeight)
                    .contentShape(Rectangle())
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewTab"))) { _ in
            tabManager.createNewTab()
        }
        .background(
            // Handle CMD+T (or CTRL+T) keyboard shortcut
            Button("New Tab") {
                tabManager.createNewTab()
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
                    return nil
                }
                return event
            }
        }
    }
    
    private func handleSearch() {
        guard !searchText.isEmpty else { return }
        print("🔍 [DEBUG] Handling search: \(searchText)")
        
        let query = searchText
        searchText = ""
        
        // Reset search field to centered after search
        withAnimation {
            isSearchActive = false
        }
        
        // Determine if it's a URL or search query
        guard let activeTab = tabManager.activeTab else { return }
        
        if query.hasPrefix("http://") || query.hasPrefix("https://") {
            activeTab.navigate(to: query)
        } else if query.contains(".") && !query.contains(" ") {
            // Likely a domain
            activeTab.navigate(to: "https://\(query)")
        } else {
            // Search query - use Google search
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            activeTab.navigate(to: "https://www.google.com/search?q=\(encodedQuery)")
            
            // Generate 3 different prompts and run them in parallel
            generateAndRunMultiplePrompts(for: query)
        }
    }
    
    private func generateAndRunMultiplePrompts(for query: String) {
        guard let activeTab = tabManager.activeTab else { return }
        
        print("🎯 [DEBUG] Generating 3 prompts for: \(query)")
        activeTab.isProcessingAI = true
        
        // Clear previous cards for this search
        activeTab.aiResponseCards.removeAll()
        
        // Auto-connect if not already connected
        if !aiService.isConnected {
            print("🔌 [DEBUG] Auto-connecting to AI service...")
            aiService.connect()
            // Wait a bit for connection to establish
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await generatePromptsAfterConnection(query: query, activeTab: activeTab)
            }
        } else {
            Task {
                await generatePromptsAfterConnection(query: query, activeTab: activeTab)
            }
        }
    }
    
    private func generatePromptsAfterConnection(query: String, activeTab: BrowserTab) async {
        // Generate 3 different prompts
        let prompts = PromptGenerator.generatePrompts(from: query)
        let selectedModel = settings.selectedModel
        var completedCount = 0
        let totalPrompts = prompts.count
        
        print("📝 [DEBUG] Generated prompts:")
        for (mode, prompt) in prompts {
            print("  - \(mode.rawValue): \(prompt)")
        }
        
        // Run all 3 prompts in parallel
        await withTaskGroup(of: (PromptMode, Result<AIResponse, Error>).self) { group in
            for (mode, prompt) in prompts {
                group.addTask {
                    do {
                        print("🚀 [DEBUG] Sending request for \(mode.rawValue) mode")
                        let response = try await aiService.sendMessage(prompt, model: selectedModel)
                        return (mode, .success(response))
                    } catch {
                        print("❌ [DEBUG] Error in \(mode.rawValue) mode: \(error.localizedDescription)")
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
                        print("✅ [DEBUG] Received response for \(mode.rawValue) mode (\(completedCount)/\(totalPrompts))")
                        
                    case .failure(let error):
                        print("❌ [DEBUG] Error for \(mode.rawValue) mode: \(error.localizedDescription)")
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
                        print("✨ [DEBUG] All \(totalPrompts) responses completed")
                    }
                }
            }
        }
    }
    
    private func handleAISearch() {
        guard !searchText.isEmpty else { return }
        let query = searchText
        searchText = ""
        
        // Reset search field to centered after AI search
        withAnimation {
            isSearchActive = false
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
        let localMouse = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { event in
            DispatchQueue.main.async {
                self.handleMouseEvent(event)
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
        
        // Get window frame
        let windowFrame = window.frame
        let mouseY = screenLocation.y - windowFrame.minY
        let windowHeight = windowFrame.height
        
        // Show search field if mouse is in top 15% of window or if mouse hasn't moved recently
        let topThreshold = windowHeight * 0.15
        let shouldShow = mouseY > (windowHeight - topThreshold) || !isScrolling
        
        updateSearchFieldVisibility(shouldShow: shouldShow)
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        // User is scrolling - hide search field
        isScrolling = true
        updateSearchFieldVisibility(shouldShow: false)
        
        // Reset scrolling flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isScrolling = false
            // Check if mouse is in top area to show search field again
            if self.mouseLocation.y > 0 {
                let window = NSApplication.shared.windows.first
                if let window = window {
                    let windowHeight = window.frame.height
                    let mouseY = self.mouseLocation.y - window.frame.minY
                    let topThreshold = windowHeight * 0.15
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
            let topThreshold = browserHeight * 0.15
            
            // Show if mouse is in top 15% of browser area
            if relativeY < topThreshold {
                updateSearchFieldVisibility(shouldShow: true)
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
            return
        }
        
        // Cancel existing timer
        hideTimer?.invalidate()
        
        if shouldShow {
            // Show immediately
            isSearchFieldVisible = true
        } else {
            // Hide after a short delay (feels more natural)
            hideTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
                DispatchQueue.main.async {
                    // Only hide if still not active and not scrolling
                    if !isSearchActive && !isScrolling {
                        isSearchFieldVisible = false
                    }
                }
            }
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
    @FocusState private var isFocused: Bool
    @State private var showModelPicker: Bool = false
    @State private var showAPIKeyDialog: Bool = false
    @State private var tempAPIKey: String = ""
    
    var body: some View {
        HStack(spacing: 8) {
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
                    // Move to bottom when focused/typing
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
        .onAppear {
            isFocused = true
        }
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

