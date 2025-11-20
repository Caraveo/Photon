import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AISettings
    @ObservedObject var aiService: LocalAIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var openAIKeyInput: String = ""
    @State private var mistralKeyInput: String = ""
    @State private var showOpenAIKey: Bool = false
    @State private var showMistralKey: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Button(action: {
                    if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                        window.close()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                Form {
                    // AI Service Settings Section
                    Section {
                        // Default AI Provider
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Default AI Provider", selection: $settings.selectedProvider) {
                                ForEach(AIProvider.allCases) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .onChange(of: settings.selectedProvider) { newProvider in
                                settings.setProvider(newProvider)
                                // Refresh available models when provider changes
                                aiService.connect()
                            }
                            
                            Text("Choose the default AI service to use for AI-powered search. Local services (MLX, Ollama) run on your machine and don't require API keys.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        // Default AI Model
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Default AI Model", selection: $settings.selectedModel) {
                                ForEach(aiService.availableModels.filter { $0.provider == settings.selectedProvider }) { model in
                                    Text(model.name).tag(model)
                                }
                            }
                            .onChange(of: settings.selectedModel) { newModel in
                                settings.setModel(newModel)
                            }
                            
                            Text("Select the specific model to use with the chosen provider. Available models depend on your provider and may be discovered automatically for local services.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        // Hide AI Service in Search
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Hide AI Service Selector in Search", isOn: Binding(
                                get: { settings.hideAIServiceInSearch },
                                set: { settings.setHideAIServiceInSearch($0) }
                            ))
                            
                            Text("When enabled, the AI service selector dropdown will be hidden in the search field. This provides a cleaner interface when you've already set your preferred default AI service and model.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("AI Service Settings")
                    }
                    
                    // API Keys Section
                    Section {
                        // OpenAI API Key
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SecureField("OpenAI API Key", text: $openAIKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Save") {
                                    settings.saveOpenAIKey(openAIKeyInput)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(openAIKeyInput.isEmpty)
                            }
                            
                            if !settings.openAIKey.isEmpty {
                                HStack {
                                    Text("✓ API Key saved")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    Button("Clear") {
                                        openAIKeyInput = ""
                                        settings.saveOpenAIKey("")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                            }
                            
                            Text("Your OpenAI API key is used to access OpenAI's models (GPT-4, GPT-3.5, etc.). Get your key from https://platform.openai.com/api-keys. The key is stored securely on your device.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        // Mistral API Key
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SecureField("Mistral AI API Key", text: $mistralKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Save") {
                                    settings.saveMistralKey(mistralKeyInput)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(mistralKeyInput.isEmpty)
                            }
                            
                            if !settings.mistralKey.isEmpty {
                                HStack {
                                    Text("✓ API Key saved")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    Button("Clear") {
                                        mistralKeyInput = ""
                                        settings.saveMistralKey("")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                            }
                            
                            Text("Your Mistral AI API key is used to access Mistral's models (Mistral Large, Medium, Small, etc.). Get your key from https://console.mistral.ai/api-keys. The key is stored securely on your device.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("API Keys")
                    } footer: {
                        Text("API keys are required for cloud-based AI services (OpenAI, Mistral). Local services (MLX, Ollama) don't require API keys.")
                    }
                    
                    // Connection Status Section
                    Section {
                        HStack {
                            Circle()
                                .fill(aiService.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(aiService.connectionStatus)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button("Connect") {
                                aiService.connect()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Text("Connection status for the currently selected AI provider. Click 'Connect' to verify your connection and fetch available models.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Connection Status")
                    }
                }
                .formStyle(.grouped)
                .padding(20)
            }
        }
        .frame(width: 700, height: 800)
        .onAppear {
            // Load current API keys into input fields (masked)
            openAIKeyInput = settings.openAIKey.isEmpty ? "" : "••••••••••••"
            mistralKeyInput = settings.mistralKey.isEmpty ? "" : "••••••••••••"
        }
    }
}

