import SwiftUI

struct MainBrowserView: View {
    init() {
        print("🚀 [DEBUG] MainBrowserView initialized")
    }
    @EnvironmentObject var browserState: BrowserState
    @EnvironmentObject var aiService: LocalAIService
    @StateObject private var settings = AISettings()
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var showURLBar: Bool = false
    @State private var isHoveringURLBar: Bool = false
    @State private var aiResponseCards: [AIResponseCard] = []
    @State private var isProcessingAI: Bool = false
    
    var body: some View {
        ZStack {
            // Main browser view - full screen
            BrowserWebViewRepresentable()
                .environmentObject(browserState)
                .ignoresSafeArea()
            
            // AI Response Cards overlay - Above search results
            VStack {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        ForEach(aiResponseCards) { card in
                            AIResponseCardView(card: card) { url in
                                browserState.navigate(to: url.absoluteString)
                            }
                            .padding(.horizontal, 40)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        if isProcessingAI {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating responses...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .padding(.horizontal, 40)
                        }
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: 500)
                Spacer()
            }
            
            // URL Bar at top - fades in/out on hover
            VStack {
                HoverableURLBar(showURLBar: $showURLBar, isHovering: $isHoveringURLBar)
                    .opacity(showURLBar ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: showURLBar)
                    .onHover { hovering in
                        isHoveringURLBar = hovering
                        withAnimation {
                            showURLBar = hovering || browserState.currentURL != nil
                        }
                    }
                Spacer()
            }
            
            // Unified Search/Input Field
            VStack {
                if !isSearchActive {
                    // Centered search field
                    UnifiedSearchField(
                        text: $searchText,
                        isActive: $isSearchActive,
                        onSearch: handleSearch,
                        onAISearch: handleAISearch
                    )
                    .frame(width: 700)
                    .environmentObject(settings)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Bottom search field
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
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSearchActive)
        }
        .onAppear {
            // Initialize AI service with settings
            aiService.settings = settings
            // Auto-connect
            if !aiService.isConnected {
                aiService.connect()
            }
        }
        .onChange(of: browserState.currentURL) { url in
            // Show URL bar when navigating
            if url != nil {
                withAnimation {
                    showURLBar = true
                }
                // Hide after 3 seconds if not hovering
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if !isHoveringURLBar {
                        withAnimation {
                            showURLBar = false
                        }
                    }
                }
            }
        }
    }
    
    private func handleSearch() {
        guard !searchText.isEmpty else { return }
        print("🔍 [DEBUG] Handling search: \(searchText)")
        isSearchActive = true
        
        let query = searchText
        searchText = ""
        
        // Determine if it's a URL or search query
        if query.hasPrefix("http://") || query.hasPrefix("https://") {
            browserState.navigate(to: query)
        } else if query.contains(".") && !query.contains(" ") {
            // Likely a domain
            browserState.navigate(to: "https://\(query)")
        } else {
            // Search query - use Google search
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            browserState.navigate(to: "https://www.google.com/search?q=\(encodedQuery)")
            
            // Generate 3 different prompts and run them in parallel
            generateAndRunMultiplePrompts(for: query)
        }
    }
    
    private func generateAndRunMultiplePrompts(for query: String) {
        print("🎯 [DEBUG] Generating 3 prompts for: \(query)")
        isProcessingAI = true
        
        // Clear previous cards for this search
        aiResponseCards.removeAll()
        
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
        Task {
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
                            aiResponseCards.insert(card, at: 0) // Insert at top
                            print("✅ [DEBUG] Received response for \(mode.rawValue) mode (\(completedCount)/\(totalPrompts))")
                            
                        case .failure(let error):
                            print("❌ [DEBUG] Error for \(mode.rawValue) mode: \(error.localizedDescription)")
                            let errorCard = AIResponseCard(
                                response: "Error: \(error.localizedDescription)",
                                relevantURL: nil,
                                query: query,
                                promptMode: mode
                            )
                            aiResponseCards.insert(errorCard, at: 0)
                        }
                        
                        // Check if all requests are done
                        if completedCount >= totalPrompts {
                            isProcessingAI = false
                            print("✨ [DEBUG] All \(totalPrompts) responses completed")
                        }
                    }
                }
            }
        }
    }
    
    private func handleAISearch() {
        guard !searchText.isEmpty else { return }
        let query = searchText
        searchText = ""
        isSearchActive = true
        
        // Use the same multi-prompt system for AI search
        generateAndRunMultiplePrompts(for: query)
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
            // Discreet Model Selector Dropdown
            ModelSelectorDropdown(
                selectedModel: $settings.selectedModel,
                availableModels: aiService.availableModels.filter { $0.provider == settings.selectedProvider },
                selectedProvider: $settings.selectedProvider,
                settings: settings,
                onProviderChange: { newProvider in
                    settings.setProvider(newProvider)
                    aiService.connect()
                },
                onAPIKeyNeeded: {
                    showAPIKeyDialog = true
                }
            )
            .frame(width: 140)
            
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
                    withAnimation {
                        isActive = true
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
                    aiService.connect()
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

struct HoverableURLBar: View {
    @Binding var showURLBar: Bool
    @Binding var isHovering: Bool
    @EnvironmentObject var browserState: BrowserState
    @State private var urlString: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { browserState.goBack() }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(!browserState.canGoBack)
            
            Button(action: { browserState.goForward() }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(!browserState.canGoForward)
            
            Button(action: { browserState.reload() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            
            TextField("URL", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    browserState.navigate(to: urlString)
                }
                .onChange(of: browserState.currentURL) { newURL in
                    if let url = newURL {
                        urlString = url.absoluteString
                    }
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 8)
        )
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}
