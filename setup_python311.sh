#!/bin/bash

# Alternative setup script using Python 3.11 (recommended for Shap-E)

set -e

echo "🚀 Setting up Prometheus 3D Generator with Python 3.11..."
echo ""

# Check if Python 3.11 is available
if ! command -v python3.11 &> /dev/null; then
    echo "❌ Python 3.11 is not installed."
    echo ""
    echo "Install Python 3.11 using one of these methods:"
    echo "1. Homebrew: brew install python@3.11"
    echo "2. pyenv: pyenv install 3.11.9"
    echo "3. Download from python.org"
    echo ""
    echo "Or use the regular setup.sh with your current Python version."
    exit 1
fi

echo "✓ Found Python 3.11"

# Remove old environment if exists
if [ -d "env" ]; then
    echo "🗑️  Removing existing environment..."
    rm -rf env
fi

# Create virtual environment with Python 3.11
echo "📦 Creating Python 3.11 virtual environment..."
python3.11 -m venv env
echo "✓ Virtual environment created"

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

# Install Shap-E from GitHub
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

