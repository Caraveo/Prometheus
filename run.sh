#!/bin/bash

# Run script for Prometheus macOS app
# This script builds and launches the app properly as a GUI application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Building Prometheus..."
echo ""

# Build the project
swift build -c release

echo ""
echo "🚀 Launching Prometheus..."
echo ""

# Get the built executable path
BUILD_DIR=".build/release"
EXECUTABLE="$BUILD_DIR/Prometheus"

# Check if executable exists
if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Executable not found at $EXECUTABLE"
    exit 1
fi

# Create app bundle in a more permanent location
APP_DIR="$SCRIPT_DIR/Prometheus.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/Prometheus"
chmod +x "$APP_DIR/Contents/MacOS/Prometheus"

# Copy Python script if it exists
if [ -f "shap_e_generator.py" ]; then
    cp "shap_e_generator.py" "$APP_DIR/Contents/Resources/"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Prometheus</string>
	<key>CFBundleIdentifier</key>
	<string>com.prometheus.3dgenerator</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Prometheus</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>LSEnvironment</key>
	<dict>
		<key>PYTHON_ENV_PATH</key>
		<string>$SCRIPT_DIR/env</string>
	</dict>
</dict>
</plist>
EOF

# Launch using open command (proper macOS app launch)
# This will launch the app and give it proper focus
open "$APP_DIR"

echo "✅ Prometheus launched!"
echo ""
echo "The app should now be running with proper focus."
echo "App bundle created at: $APP_DIR"

