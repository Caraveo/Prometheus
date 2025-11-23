#!/bin/bash

# Build script for Prometheus macOS app

set -e

echo "🔨 Building Prometheus..."
echo ""

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed. Please install Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

# Build the project
swift build -c release

echo ""
echo "✅ Build complete!"
echo ""
echo "To run the app with proper focus:"
echo "  ./run.sh"
echo ""
echo "Or run directly (may have focus issues):"
echo "  swift run Prometheus"
echo ""
echo "Or create an Xcode project:"
echo "  swift package generate-xcodeproj"

