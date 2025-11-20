#!/bin/bash
# Code signing script for Photon.app
# Usage: ./sign.sh [IDENTITY_NAME]
#   - If no argument, will auto-detect available signing identity
#   - Can specify full identity name or Team ID

set -e

APP_BUNDLE="Photon.app"
BUNDLE_ID="com.caraveo.Photon"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Please build the app first."
    exit 1
fi

# Clean resource forks and Finder metadata (required for code signing)
echo "Cleaning resource forks and metadata..."
find "$APP_BUNDLE" -type f -exec xattr -c {} \; 2>/dev/null || true
find "$APP_BUNDLE" -type f -exec xattr -d com.apple.ResourceFork {} \; 2>/dev/null || true
find "$APP_BUNDLE" -type f -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true

# Function to find signing identity
find_signing_identity() {
    local identity_type="$1"
    
    # Try to find Developer ID first (for distribution)
    if [ "$identity_type" = "Developer ID" ] || [ -z "$identity_type" ]; then
        local dev_id=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
        if [ -n "$dev_id" ]; then
            echo "$dev_id"
            return 0
        fi
    fi
    
    # Fallback to Apple Development (for testing)
    if [ "$identity_type" = "Apple Development" ] || [ -z "$identity_type" ]; then
        local apple_dev=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/')
        if [ -n "$apple_dev" ]; then
            echo "$apple_dev"
            return 0
        fi
    fi
    
    return 1
}

# Get identity from argument or auto-detect
IDENTITY="${1}"

if [ -z "$IDENTITY" ]; then
    echo "Auto-detecting signing identity..."
    IDENTITY=$(find_signing_identity)
    
    if [ -z "$IDENTITY" ]; then
        echo "Error: No signing identity found."
        echo ""
        echo "Available identities:"
        security find-identity -v -p codesigning
        echo ""
        echo "Usage: ./sign.sh \"IDENTITY_NAME\""
        echo "Example: ./sign.sh \"Developer ID Application: Your Name (TEAM_ID)\""
        exit 1
    fi
fi

echo "Signing Photon.app with identity: $IDENTITY"
echo ""

# Sign the executable
echo "Signing executable..."
codesign --force --deep --sign "$IDENTITY" \
    --options runtime \
    --entitlements entitlements.plist \
    "$APP_BUNDLE/Contents/MacOS/Photon"

# Sign the app bundle
echo "Signing app bundle..."
codesign --force --deep --sign "$IDENTITY" \
    --options runtime \
    --entitlements entitlements.plist \
    "$APP_BUNDLE"

# Verify signing
echo ""
echo "Verifying code signature..."
if codesign --verify --verbose "$APP_BUNDLE" 2>&1; then
    echo "✅ Code signature verified!"
else
    echo "❌ Code signature verification failed!"
    exit 1
fi

echo ""
echo "Code signing details:"
codesign --display --verbose=4 "$APP_BUNDLE" 2>&1 | head -20

echo ""
echo "✅ Code signing complete!"
echo ""
echo "To verify with Gatekeeper:"
echo "  spctl --assess --verbose $APP_BUNDLE"
echo ""
echo "Note: For distribution outside App Store, you need 'Developer ID Application' certificate."
echo "      For testing, 'Apple Development' certificate works but requires notarization for distribution."

