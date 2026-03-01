#!/bin/bash
set -e

echo "=== MusicBrowser Project Setup ==="

# Check for xcodegen
if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not found. Install from https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi

echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "Done! Opening MusicBrowser.xcodeproj..."
echo ""
echo "IMPORTANT: Before building, you must:"
echo "  1. Select your Apple Developer team in Signing & Capabilities"
echo "  2. The MusicKit entitlement requires an Apple Developer account"
echo "  3. On first run, the app will request Apple Music access"
echo ""

open MusicBrowser.xcodeproj
