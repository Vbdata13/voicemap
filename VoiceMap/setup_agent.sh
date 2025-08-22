#!/bin/bash

# VoiceMap LiveKit Agent Setup Script

echo "🚀 Setting up VoiceMap LiveKit Agent..."

# Check if Python 3.8+ is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo "🐍 Using Python $PYTHON_VERSION"

# Create virtual environment
echo "📦 Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "⚡ Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your actual API keys!"
else
    echo "✅ .env file already exists"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "To run the agent:"
echo "1. Edit .env file with your API keys"
echo "2. Activate the virtual environment: source venv/bin/activate"
echo "3. Run the agent: python livekit_agent.py connect --room voicemap-room"
echo ""
echo "For development mode (waits for any room):"
echo "python livekit_agent.py dev"
echo ""
echo "For production deployment:"
echo "python livekit_agent.py start"