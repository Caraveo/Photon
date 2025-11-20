import Foundation

// Import SearchEngine
extension AISettings {
    // SearchEngine is defined in SearchEngine.swift
}

enum SearchFieldPosition: String, CaseIterable, Identifiable {
    case top = "Top"
    case bottom = "Bottom"
    
    var id: String { rawValue }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case mlx = "MLX (Local)"
    case ollama = "Ollama (Local)"
    case openai = "OpenAI"
    case mistral = "Mistral AI"
    
    var id: String { rawValue }
    
    var baseURL: String {
        switch self {
        case .mlx:
            return "http://localhost:11973"
        case .ollama:
            return "http://localhost:11434"
        case .openai:
            return "https://api.openai.com"
        case .mistral:
            return "https://api.mistral.ai"
        }
    }
}

struct AIModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: AIProvider
    
    static let defaultModels: [AIModel] = [
        AIModel(id: "gpt-4", name: "GPT-4", provider: .openai),
        AIModel(id: "gpt-4-turbo", name: "GPT-4 Turbo", provider: .openai),
        AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openai),
        AIModel(id: "mistral-medium", name: "Mistral Medium", provider: .mistral),
        AIModel(id: "mistral-large", name: "Mistral Large", provider: .mistral),
        AIModel(id: "mistral-small", name: "Mistral Small", provider: .mistral),
        AIModel(id: "mlx-default", name: "MLX Default", provider: .mlx),
    ]
}

class AISettings: ObservableObject {
    @Published var selectedProvider: AIProvider = .mlx
    @Published var selectedModel: AIModel = AIModel.defaultModels.first { $0.provider == .mlx } ?? AIModel.defaultModels[0]
    @Published var openAIKey: String = ""
    @Published var mistralKey: String = ""
    @Published var availableModels: [AIModel] = AIModel.defaultModels
    @Published var hideAIServiceInSearch: Bool = false
    @Published var searchFieldPosition: SearchFieldPosition = .bottom
    @Published var selectedSearchEngine: SearchEngine = .google
    @Published var hasCompletedOnboarding: Bool = false
    
    private let openAIKeyKey = "openai_api_key"
    private let mistralKeyKey = "mistral_api_key"
    private let selectedProviderKey = "selected_ai_provider"
    private let selectedModelKey = "selected_ai_model"
    private let hideAIServiceKey = "hide_ai_service_in_search"
    private let searchFieldPositionKey = "search_field_position"
    private let selectedSearchEngineKey = "selected_search_engine"
    private let hasCompletedOnboardingKey = "has_completed_onboarding"
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load OpenAI key
        if let key = UserDefaults.standard.string(forKey: openAIKeyKey) {
            openAIKey = key
        }
        
        // Load Mistral key
        if let key = UserDefaults.standard.string(forKey: mistralKeyKey) {
            mistralKey = key
        }
        
        // Load selected provider
        if let providerString = UserDefaults.standard.string(forKey: selectedProviderKey),
           let provider = AIProvider(rawValue: providerString) {
            selectedProvider = provider
        }
        
        // Load selected model - try availableModels first, then defaultModels
        if let modelId = UserDefaults.standard.string(forKey: selectedModelKey) {
            if let model = availableModels.first(where: { $0.id == modelId }) {
                selectedModel = model
            } else if let model = AIModel.defaultModels.first(where: { $0.id == modelId }) {
                selectedModel = model
            }
        }
        
        // Load hide AI service setting
        hideAIServiceInSearch = UserDefaults.standard.bool(forKey: hideAIServiceKey)
        
        // Load search field position
        if let positionString = UserDefaults.standard.string(forKey: searchFieldPositionKey),
           let position = SearchFieldPosition(rawValue: positionString) {
            searchFieldPosition = position
        }
        
        // Load selected search engine
        if let engineString = UserDefaults.standard.string(forKey: selectedSearchEngineKey),
           let engine = SearchEngine(rawValue: engineString) {
            selectedSearchEngine = engine
        }
        
        // Load onboarding status
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }
    
    func saveOpenAIKey(_ key: String) {
        openAIKey = key
        UserDefaults.standard.set(key, forKey: openAIKeyKey)
        UserDefaults.standard.synchronize()
    }
    
    func saveMistralKey(_ key: String) {
        mistralKey = key
        UserDefaults.standard.set(key, forKey: mistralKeyKey)
        UserDefaults.standard.synchronize()
    }
    
    func setProvider(_ provider: AIProvider) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: selectedProviderKey)
        UserDefaults.standard.synchronize()
        
        // Update selected model to first available for this provider
        if let firstModel = availableModels.first(where: { $0.provider == provider }) {
            setModel(firstModel)
        }
    }
    
    func setModel(_ model: AIModel) {
        selectedModel = model
        UserDefaults.standard.set(model.id, forKey: selectedModelKey)
        UserDefaults.standard.synchronize()
    }
    
    func setHideAIServiceInSearch(_ hide: Bool) {
        hideAIServiceInSearch = hide
        UserDefaults.standard.set(hide, forKey: hideAIServiceKey)
        UserDefaults.standard.synchronize()
    }
    
    func setSearchFieldPosition(_ position: SearchFieldPosition) {
        searchFieldPosition = position
        UserDefaults.standard.set(position.rawValue, forKey: searchFieldPositionKey)
        UserDefaults.standard.synchronize()
    }
    
    func setSearchEngine(_ engine: SearchEngine) {
        selectedSearchEngine = engine
        UserDefaults.standard.set(engine.rawValue, forKey: selectedSearchEngineKey)
        UserDefaults.standard.synchronize()
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        UserDefaults.standard.synchronize()
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
        UserDefaults.standard.synchronize()
    }
}

