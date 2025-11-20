# Photon Browser v1.0.0

## 🎉 Initial Release

Photon is a modern macOS browser built with SwiftUI and WebKit, featuring integrated AI support and a beautiful, unified interface.

## ✨ Key Features

### Core Browser
- **WebKit-based Rendering**: Fast, native web content rendering using WKWebView
- **Tab System**: Multiple tabs with keyboard shortcuts (CMD+T/CTRL+T)
- **Tab Freezing**: Tabs are frozen when inactive to prevent page reloads
- **Navigation Controls**: Back, forward, and refresh buttons in the search field

### AI Integration
- **Multiple AI Providers**:
  - MLX (Local) - Running on `http://localhost:11973`
  - Ollama (Local) - Running on `http://localhost:11434`
  - OpenAI - Cloud-based AI service
  - Mistral AI - Cloud-based AI service
- **AI Response Cards**: Beautiful card-based UI displaying AI responses with relevant URLs
- **Dynamic Model Discovery**: Automatically discovers available models from local AI services

### User Interface
- **Dynamic Search Field**: Intelligent search field that hides/shows based on user interaction
- **Search Field Positioning**: Configurable TOP or BOTTOM positioning (Settings → AI Service Settings)
- **Centered Search on Launch**: Search field appears centered on app launch or new tab creation
- **Smooth Animations**: Modern SwiftUI animations and transitions

### Settings & Persistence
- **Persistent Settings**: All settings (AI provider, model, API keys, search position) persist between launches
- **Settings Panel**: Accessible via `File → Settings` or `CMD+,`
- **API Key Management**: Secure storage of OpenAI and Mistral API keys
- **Connection Status**: Real-time connection status for AI providers

## 📋 System Requirements

- macOS 13.0 or later
- Apple Silicon (arm64) or Intel Mac
- For local AI services (optional):
  - MLX service running on port 11973
  - Ollama service running on port 11434

## 🚀 Installation

1. Download `Photon-v1.0.0-macOS.zip` from the releases page
2. Extract the zip file
3. Move `Photon.app` to your Applications folder
4. Double-click to launch

## 🎮 Usage

### Basic Navigation
- **Search**: Type in the search field and press Enter
- **AI Search**: Click the "AI" button in the search field
- **New Tab**: Press `CMD+T` or `CTRL+T`
- **Settings**: Press `CMD+,` or go to `File → Settings`

### AI Features
1. Open Settings (`CMD+,`)
2. Select your AI provider
3. For cloud services (OpenAI, Mistral), enter your API key
4. Click "Connect" to verify connection and discover models
5. Use the AI search feature to get AI-powered responses

## 🔧 Recent Improvements

- ✅ Settings persistence between launches
- ✅ Search field position configuration (TOP/BOTTOM)
- ✅ Navigation controls (back, forward, refresh)
- ✅ Tab system with keyboard shortcuts
- ✅ Dynamic search field visibility
- ✅ AI response cards with URL discovery
- ✅ Multiple AI provider support
- ✅ App bundle packaging with custom icon

## 📝 Notes

- The app requires macOS 13.0 or later
- Local AI services (MLX, Ollama) are optional
- API keys for cloud services are stored securely using UserDefaults
- All settings are automatically saved and restored on app launch

## 🐛 Known Issues

None at this time. Please report any issues on the GitHub Issues page.

## 🙏 Acknowledgments

Built with SwiftUI, WebKit, and modern macOS technologies.

---

**Download**: [Photon-v1.0.0-macOS.zip](Photon-v1.0.0-macOS.zip)

