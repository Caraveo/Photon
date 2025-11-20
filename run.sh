#!/bin/bash
# Launch Photon browser as a GUI application

cd "$(dirname "$0")"

# Build if needed
if [ ! -f ".build/arm64-apple-macosx/debug/Photon" ]; then
    echo "Building Photon..."
    swift build
fi

# Run in background and detach from terminal
echo "Launching Photon browser..."
echo "The app window should appear shortly. If not, check your Dock."
echo "Press Ctrl+C in this terminal to stop the app when done."

# Run the app - it will show a window
swift run Photon

