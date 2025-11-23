#!/bin/bash

# Download MaterialAnything models from HuggingFace

set -e

echo "📥 Downloading MaterialAnything models..."
echo ""

# Check if git-lfs is installed
if ! command -v git-lfs &> /dev/null; then
    echo "⚠️  git-lfs is not installed. Installing..."
    if command -v brew &> /dev/null; then
        brew install git-lfs
        git lfs install
    else
        echo "❌ Please install git-lfs manually:"
        echo "   brew install git-lfs"
        echo "   git lfs install"
        exit 1
    fi
fi

# Create pretrained_models directory
mkdir -p pretrained_models
cd pretrained_models/

# Download material estimator
if [ ! -d "material_estimator" ]; then
    echo "📦 Downloading material_estimator..."
    git lfs clone https://huggingface.co/xanderhuang/material_estimator
    echo "✓ material_estimator downloaded"
else
    echo "✓ material_estimator already exists"
fi

# Download material refiner
if [ ! -d "material_refiner" ]; then
    echo "📦 Downloading material_refiner..."
    git lfs clone https://huggingface.co/xanderhuang/material_refiner
    echo "✓ material_refiner downloaded"
else
    echo "✓ material_refiner already exists"
fi

cd ..

echo ""
echo "✅ MaterialAnything models downloaded successfully!"
echo ""
echo "Models are located in: pretrained_models/"

