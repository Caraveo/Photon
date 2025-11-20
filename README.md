# Photon Browser

A modern macOS browser built with SwiftUI, Chromium (WebKit), and integrated local MLX AI support.

## Features

- **Chromium-based Rendering**: Uses WKWebView (WebKit) for web content rendering
- **SwiftUI Interface**: Modern, native macOS UI
- **AI Conduit Bar**: Middle panel for interacting with local MLX AI
- **METAL Bridge**: Swift/TypeScript communication layer for seamless integration

## Architecture

### Components

1. **BrowserView**: Main browser interface with navigation controls
2. **AIConduitBar**: Middle panel for AI interactions
3. **LocalAIService**: Service for communicating with local MLX AI instance
4. **MetalBridge**: Swift/TypeScript bridge for cross-layer communication

### Data Flow (Conduit)

```
View (SwiftUI) → BrowserState → WebView (WKWebView)
                ↓
            AIConduitBar → LocalAIService → MetalBridge → TypeScript Bridge → MLX AI (localhost:11973)
```

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- Local MLX AI service running on port 11973

## Setup

1. **Install Dependencies**:
   ```bash
   swift build
   ```

2. **Start Local MLX AI Service**:
   Ensure your MLX AI service is running on `http://localhost:11973`

3. **Run the Application**:
   ```bash
   swift run Photon
   ```

## Project Structure

```
Photon/
├── Sources/
│   ├── PhotonApp.swift          # Main app entry point
│   ├── Models/
│   │   └── BrowserState.swift    # Browser state management
│   ├── Views/
│   │   ├── MainBrowserView.swift # Main layout
│   │   ├── BrowserView.swift     # Browser component
│   │   └── AIConduitBar.swift    # AI interaction panel
│   ├── Services/
│   │   └── LocalAIService.swift  # AI service integration
│   └── Bridge/
│       ├── MetalBridge.swift     # Swift bridge implementation
│       └── typescript-bridge.ts  # TypeScript bridge
├── Package.swift                 # Swift Package Manager config
└── README.md
```

## METAL Bridge

The METAL (Swift/TypeScript) bridge enables communication between:
- Swift layer (native macOS code)
- TypeScript layer (web content scripts)
- Local AI service (MLX AI)

This allows web pages to interact with the local AI service through the native Swift layer.

## Development

### Building for Production

```bash
swift build -c release
```

### Running Tests

```bash
swift test
```

## License

MIT License

