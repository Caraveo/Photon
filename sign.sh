#!/bin/bash
# Code signing script for Photon.app
# Usage: ./sign.sh [TEAM_ID]

set -e

APP_BUNDLE="Photon.app"
BUNDLE_ID="com.caraveo.Photon"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Please build the app first."
    exit 1
fi

# Get team ID from argument or environment variable
TEAM_ID="${1:-${TEAM_ID}}"

if [ -z "$TEAM_ID" ]; then
    echo "Usage: ./sign.sh [TEAM_ID]"
    echo "Or set TEAM_ID environment variable"
    echo ""
    echo "Finding available signing identities..."
    security find-identity -v -p codesigning | grep "Developer ID Application" || security find-identity -v -p codesigning | grep "Apple Development"
    echo ""
    echo "Please provide your Team ID (found in Apple Developer account)"
    exit 1
fi

echo "Signing Photon.app with Team ID: $TEAM_ID"

# Sign the executable
echo "Signing executable..."
codesign --force --deep --sign "Developer ID Application: $TEAM_ID" \
    --options runtime \
    --entitlements entitlements.plist \
    "$APP_BUNDLE/Contents/MacOS/Photon"

# Sign the app bundle
echo "Signing app bundle..."
codesign --force --deep --sign "Developer ID Application: $TEAM_ID" \
    --options runtime \
    --entitlements entitlements.plist \
    "$APP_BUNDLE"

# Verify signing
echo ""
echo "Verifying code signature..."
codesign --verify --verbose "$APP_BUNDLE"
codesign --display --verbose=4 "$APP_BUNDLE"

echo ""
echo "✅ Code signing complete!"
echo ""
echo "To check signing details:"
echo "  codesign -dv --verbose=4 $APP_BUNDLE"
echo ""
echo "To verify:"
echo "  spctl --assess --verbose $APP_BUNDLE"

