# Photon Browser

A modern macOS browser built with SwiftUI, WebKit, and integrated local AI support (MLX, Ollama, OpenAI, Mistral).

## Features

- **WebKit-based Rendering**: Uses WKWebView for fast, native web content rendering
- **SwiftUI Interface**: Modern, native macOS UI with smooth animations
- **AI Integration**: Support for multiple AI providers:
  - MLX (Local) - Running on `http://localhost:11973`
  - Ollama (Local) - Running on `http://localhost:11434`
  - OpenAI - Cloud-based AI service
  - Mistral AI - Cloud-based AI service
- **Tab System**: Multiple tabs with keyboard shortcuts (CMD+T/CTRL+T)
- **Dynamic Search Field**: Intelligent search field that hides/shows based on user interaction
- **AI Response Cards**: Beautiful card-based UI for AI responses with relevant URLs
- **METAL Bridge**: Swift/TypeScript communication layer for seamless integration
- **Tab Freezing**: Tabs are frozen when inactive to prevent page reloads

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- For local AI services:
  - MLX service running on port 11973 (optional)
  - Ollama service running on port 11434 (optional)

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/caraveo/Photon.git
   cd Photon
   ```

2. **Build the project**:
   ```bash
   swift build
   ```

3. **Run the application**:
   ```bash
   swift run Photon
   ```

   Or use the launch script:
   ```bash
   ./run.sh
   ```

## Usage

### Basic Navigation

- **Search**: Type in the search field and press Enter to search
- **AI Search**: Click the "AI" button or use the AI search feature
- **New Tab**: Press `CMD+T` or `CTRL+T`
- **Navigation**: Use the `<`, `>`, and refresh icons in the search field

### AI Features

1. **Connect AI Service**:
   - Go to `File → Settings` (or press `CMD+,`)
   - Select your AI provider
   - For cloud services (OpenAI, Mistral), enter your API key
   - Click "Connect" to verify connection

2. **Use AI Search**:
   - Type your query in the search field
   - Click the "AI" button to get AI-powered responses
   - View responses as cards with relevant URLs

3. **Settings**:
   - Hide AI service selector in search field for a cleaner interface
   - Choose default AI provider and model
   - Manage API keys securely

## Project Structure

```
Photon/
├── Sources/
│   ├── PhotonApp.swift              # Main app entry point
│   ├── Models/
│   │   ├── BrowserState.swift       # Browser state management
│   │   ├── Tab.swift                # Tab management
│   │   ├── AIProvider.swift         # AI provider definitions
│   │   └── AIResponse.swift         # AI response data structures
│   ├── Views/
│   │   ├── MainBrowserView.swift    # Main layout
│   │   ├── BrowserView.swift        # Browser component
│   │   ├── TabBarView.swift         # Tab bar UI
│   │   ├── TabBrowserView.swift     # Tab content view
│   │   ├── AIComponents.swift       # AI-related UI components
│   │   └── SettingsView.swift       # Settings panel
│   ├── Services/
│   │   ├── LocalAIService.swift     # AI service integration
│   │   └── PromptGenerator.swift    # AI prompt generation
│   └── Bridge/
│       ├── MetalBridge.swift        # Swift bridge implementation
│       └── typescript-bridge.ts     # TypeScript bridge
├── Package.swift                    # Swift Package Manager config
└── README.md
```

## Architecture

### Components

1. **MainBrowserView**: Main browser interface orchestrating all components
2. **TabManager**: Manages multiple browser tabs with independent states
3. **LocalAIService**: Handles communication with AI providers
4. **MetalBridge**: Swift/TypeScript bridge for cross-layer communication

### Data Flow

```
View (SwiftUI) → BrowserState/TabManager → WebView (WKWebView)
                ↓
            UnifiedSearchField → LocalAIService → AI Providers
                ↓
            AI Response Cards → Display Results
```

## Development

### Building for Production

```bash
swift build -c release
```

### Code Signing

To sign the app with your Apple Developer account:

1. **Get your Team ID** from [Apple Developer Account](https://developer.apple.com/account)

2. **Sign the app**:
   ```bash
   ./sign.sh YOUR_TEAM_ID
   ```
   
   Or set the `TEAM_ID` environment variable:
   ```bash
   export TEAM_ID="YOUR_TEAM_ID"
   ./sign.sh
   ```

3. **Verify signing**:
   ```bash
   codesign -dv --verbose=4 Photon.app
   spctl --assess --verbose Photon.app
   ```

**Note**: Code signing requires:
- Valid Apple Developer account
- "Developer ID Application" certificate installed in Keychain
- Team ID from your developer account

### Running Tests

```bash
swift test
```

## Keyboard Shortcuts

- `CMD+T` / `CTRL+T`: New tab
- `CMD+,`: Open Settings
- `Enter`: Search/Navigate
- `ESC`: Close AI cards (when visible)

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
