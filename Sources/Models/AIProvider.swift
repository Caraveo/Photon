import Foundation

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
    
    private let openAIKeyKey = "openai_api_key"
    private let mistralKeyKey = "mistral_api_key"
    private let selectedProviderKey = "selected_ai_provider"
    private let selectedModelKey = "selected_ai_model"
    private let hideAIServiceKey = "hide_ai_service_in_search"
    
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
        
        // Load selected model
        if let modelId = UserDefaults.standard.string(forKey: selectedModelKey),
           let model = availableModels.first(where: { $0.id == modelId }) {
            selectedModel = model
        }
        
        // Load hide AI service setting
        hideAIServiceInSearch = UserDefaults.standard.bool(forKey: hideAIServiceKey)
    }
    
    func saveOpenAIKey(_ key: String) {
        openAIKey = key
        UserDefaults.standard.set(key, forKey: openAIKeyKey)
    }
    
    func saveMistralKey(_ key: String) {
        mistralKey = key
        UserDefaults.standard.set(key, forKey: mistralKeyKey)
    }
    
    func setProvider(_ provider: AIProvider) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: selectedProviderKey)
        
        // Update selected model to first available for this provider
        if let firstModel = availableModels.first(where: { $0.provider == provider }) {
            setModel(firstModel)
        }
    }
    
    func setModel(_ model: AIModel) {
        selectedModel = model
        UserDefaults.standard.set(model.id, forKey: selectedModelKey)
    }
    
    func setHideAIServiceInSearch(_ hide: Bool) {
        hideAIServiceInSearch = hide
        UserDefaults.standard.set(hide, forKey: hideAIServiceKey)
    }
}

