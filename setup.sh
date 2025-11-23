#!/bin/bash

# Prometheus Setup Script
# This script sets up the Python environment and installs dependencies

set -e

echo "🚀 Setting up Prometheus 3D Generator..."
echo ""

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.9 or later."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

echo "✓ Found Python $PYTHON_VERSION"

# Check Python version compatibility (Shap-E works best with 3.9-3.11)
if [ "$PYTHON_MAJOR" -gt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -gt 11 ]); then
    echo "⚠️  Warning: Python $PYTHON_VERSION may not be fully compatible with Shap-E"
    echo "   Recommended: Python 3.9, 3.10, or 3.11"
    echo "   Continuing anyway..."
    echo ""
fi

# Create virtual environment if it doesn't exist
if [ ! -d "env" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv env
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source env/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip --quiet

# Install requirements
echo "📥 Installing Python dependencies..."
echo "   This may take a few minutes..."
pip install -r requirements.txt

# Install Shap-E from GitHub (not available on PyPI)
echo ""
echo "📦 Installing Shap-E from GitHub..."
echo "   This may take a few minutes..."
pip install git+https://github.com/openai/shap-e.git

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Open the project in Xcode or build with: swift build"
echo "2. Run the app and start generating 3D models!"
echo ""
echo "Note: First generation will download Shap-E models (~2GB)"
echo "      This may take 5-10 minutes depending on your connection."

