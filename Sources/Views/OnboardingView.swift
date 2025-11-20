import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var settings: AISettings
    @ObservedObject var aiService: LocalAIService
    @State private var currentStep: OnboardingStep = .searchEngine
    @State private var selectedSearchEngine: SearchEngine = .google
    @State private var selectedAICategory: AICategory = .local
    @State private var selectedProvider: AIProvider = .ollama
    @State private var selectedModel: AIModel?
    @State private var isConnecting: Bool = false
    
    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                if currentStep != .complete {
                    ProgressView(value: currentStep.progress)
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                }
                
                // Content
                ScrollView {
                    VStack(spacing: 40) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Welcome to Photon")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Let's set up your browsing experience")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                        
                        // Step content
                        switch currentStep {
                        case .searchEngine:
                            searchEngineSelection
                        case .aiModel:
                            aiModelSelection
                        case .complete:
                            completionView
                        }
                    }
                    .frame(maxWidth: 800)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Search Engine Selection
    
    private var searchEngineSelection: some View {
        VStack(spacing: 30) {
            Text("Choose Your Search Engine")
                .font(.system(size: 28, weight: .semibold))
                .padding(.bottom, 10)
            
            HStack(spacing: 24) {
                ForEach(SearchEngine.allCases) { engine in
                    SearchEngineCard(
                        engine: engine,
                        isSelected: selectedSearchEngine == engine
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSearchEngine = engine
                        }
                    }
                }
            }
            
            Button(action: {
                settings.setSearchEngine(selectedSearchEngine)
                
                // Skip AI setup for Google and DuckDuckGo, go directly to browser
                if selectedSearchEngine == .google || selectedSearchEngine == .duckduckgo {
                    settings.completeOnboarding()
                    // Connect to AI service (will be used for Photon Search if selected later)
                    aiService.connect()
                } else {
                    // Show AI setup for Photon Search
                    withAnimation {
                        currentStep = .aiModel
                    }
                }
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
    }
    
    // MARK: - AI Model Selection
    
    private var aiModelSelection: some View {
        VStack(spacing: 30) {
            Text("Choose Your AI")
                .font(.system(size: 28, weight: .semibold))
                .padding(.bottom, 10)
            
            // AI Category Selection
            HStack(spacing: 20) {
                AICategoryCard(
                    category: .local,
                    isSelected: selectedAICategory == .local
                ) {
                    withAnimation {
                        selectedAICategory = .local
                        // Auto-select first local provider
                        if let firstLocal = AIProvider.allCases.first(where: { $0 == .ollama || $0 == .mlx }) {
                            selectedProvider = firstLocal
                        }
                    }
                }
                
                AICategoryCard(
                    category: .cloud,
                    isSelected: selectedAICategory == .cloud
                ) {
                    withAnimation {
                        selectedAICategory = .cloud
                        // Auto-select first cloud provider
                        if let firstCloud = AIProvider.allCases.first(where: { $0 == .openai || $0 == .mistral }) {
                            selectedProvider = firstCloud
                        }
                    }
                }
            }
            
            // Provider Selection
            if selectedAICategory == .local {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Local AI Provider")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        ForEach([AIProvider.ollama, AIProvider.mlx]) { provider in
                            ProviderCard(
                                provider: provider,
                                isSelected: selectedProvider == provider
                            ) {
                                withAnimation {
                                    selectedProvider = provider
                                    selectedModel = nil
                                }
                                Task {
                                    await connectToProvider(provider)
                                }
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cloud AI Provider")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        ForEach([AIProvider.openai, AIProvider.mistral]) { provider in
                            ProviderCard(
                                provider: provider,
                                isSelected: selectedProvider == provider
                            ) {
                                withAnimation {
                                    selectedProvider = provider
                                    selectedModel = nil
                                }
                            }
                        }
                    }
                }
            }
            
            // Model Selection
            if let models = getAvailableModels(for: selectedProvider), !models.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Model")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(models) { model in
                                ModelCard(
                                    model: model,
                                    isSelected: selectedModel?.id == model.id
                                ) {
                                    withAnimation {
                                        selectedModel = model
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation {
                        currentStep = .searchEngine
                    }
                }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if let model = selectedModel {
                        settings.setProvider(selectedProvider)
                        settings.setModel(model)
                    }
                    settings.completeOnboarding()
                    withAnimation {
                        currentStep = .complete
                    }
                }) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(isConnecting ? "Connecting..." : "Complete Setup")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(selectedModel == nil || isConnecting)
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.system(size: 32, weight: .bold))
            
            Text("Photon is ready to use. Start browsing with your personalized settings.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                settings.completeOnboarding()
                // Connect to AI service if not already connected
                aiService.connect()
            }) {
                Text("Start Browsing")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAvailableModels(for provider: AIProvider) -> [AIModel]? {
        return aiService.availableModels.filter { $0.provider == provider }
    }
    
    private func connectToProvider(_ provider: AIProvider) async {
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.isConnecting = true
        }
        
        // Connect to provider
        aiService.connect()
        
        // Wait a bit for models to load
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.isConnecting = false
            // Auto-select first model if available
            if let models = self.getAvailableModels(for: provider),
               let firstModel = models.first,
               self.selectedModel == nil {
                self.selectedModel = firstModel
            }
        }
    }
}

// MARK: - Supporting Views

struct SearchEngineCard: View {
    let engine: SearchEngine
    let isSelected: Bool
    let action: () -> Void
    @State private var logoImage: NSImage?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                Group {
                    if let logoName = engine.logoImageName {
                        if let image = logoImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: engine.icon)
                                .font(.system(size: 48))
                                .foregroundColor(isSelected ? .white : .blue)
                        }
                    } else {
                        Image(systemName: engine.icon)
                            .font(.system(size: 48))
                            .foregroundColor(isSelected ? .white : .blue)
                    }
                }
                .frame(width: 100, height: 100)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color(NSColor.controlBackgroundColor))
                )
                .onAppear {
                    loadLogo()
                }
                
                Text(engine.rawValue)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(engine.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 220, height: 240)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isSelected ? 3 : 0)
                    )
                    .shadow(color: isSelected ? .black.opacity(0.2) : .black.opacity(0.1), radius: isSelected ? 12 : 6, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AICategoryCard: View {
    let category: AICategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: category.icon)
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .white : category.color)
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(isSelected ? category.color : Color(NSColor.controlBackgroundColor))
                    )
                
                Text(category.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(category.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: isSelected ? .black.opacity(0.15) : .black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderCard: View {
    let provider: AIProvider
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: provider == .ollama ? "server.rack" : provider == .mlx ? "cpu" : "cloud")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(provider.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color(NSColor.separatorColor), lineWidth: 1)
            )
            .shadow(color: isSelected ? .black.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ModelCard: View {
    let model: AIModel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(model.name)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : Color(NSColor.separatorColor), lineWidth: 1)
                )
                .shadow(color: isSelected ? .black.opacity(0.1) : .clear, radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enums

enum OnboardingStep {
    case searchEngine
    case aiModel
    case complete
    
    var progress: Double {
        switch self {
        case .searchEngine: return 0.33
        case .aiModel: return 0.66
        case .complete: return 1.0
        }
    }
}

enum AICategory {
    case local
    case cloud
    
    var title: String {
        switch self {
        case .local: return "Local AI"
        case .cloud: return "Cloud AI"
        }
    }
    
    var description: String {
        switch self {
        case .local: return "Runs on your Mac\nPrivate & Fast"
        case .cloud: return "Powered by APIs\nAdvanced Models"
        }
    }
    
    var icon: String {
        switch self {
        case .local: return "cpu"
        case .cloud: return "cloud"
        }
    }
    
    var color: Color {
        switch self {
        case .local: return .green
        case .cloud: return .blue
        }
    }
}

