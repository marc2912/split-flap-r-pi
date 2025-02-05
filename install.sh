#!/bin/bash

set -e
set -o pipefail
set -u

LOG_FILE="$HOME/splitflap_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔄 Starting SplitFlap installation..."

# Ensure script is NOT run as root
if [ "$(id -u)" -eq 0 ]; then
    echo "❌ Do NOT run this script as root. Run it as a regular user."
    exit 1
fi

# Get the username of the current user
USERNAME="$(whoami)"
APP_DIR="$HOME/splitflap"

# Function to retry commands
retry() {
    local n=1
    local max=3
    local delay=5
    while true; do
        "$@" && break || {
            if [[ $n -lt $max ]]; then
                ((n++))
                echo "⚠️ Command failed. Attempt $n/$max: $@"
                sleep $delay;
            else
                echo "❌ Command failed after $max attempts: $@"
                exit 1
            fi
        }
    done
}

# Update system packages
echo "📦 Updating system packages..."
retry sudo apt-get update
retry sudo apt-get upgrade -y

# Install dependencies
echo "📦 Installing required dependencies..."
retry sudo apt-get install -y curl

# Install Node.js v22.13.1 from NodeSource
echo "🔧 Installing Node.js v22.13.1..."
retry curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
retry sudo apt-get install -y nodejs

# Verify Node.js version
echo "✅ Node.js version: $(node -v)"

# Ensure splitflap directory exists
echo "📂 Ensuring correct permissions for $APP_DIR..."
mkdir -p "$APP_DIR"
chmod -R 755 "$APP_DIR"

# Move into app directory
cd "$APP_DIR"

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install --omit=dev

# Compile TypeScript
echo "🔧 Compiling TypeScript..."
npm run build

# Install PM2 globally for the user
echo "📦 Installing PM2..."
npm install -g pm2

# Ensure PM2 starts on boot
echo "🔄 Configuring PM2 for auto-start..."
pm2 startup systemd -u "$USERNAME" --hp "$HOME"

# Start SplitFlap with PM2
echo "🚀 Starting SplitFlap with PM2..."
pm2 start "$APP_DIR/dist/server.js" --name splitflap

# Save PM2 process list to ensure auto-restart on boot
echo "💾 Saving PM2 process list..."
pm2 save

# Enable PM2 service to start on boot
echo "🔄 Enabling PM2 service..."
systemctl --user enable pm2-"$USERNAME"
systemctl --user restart pm2-"$USERNAME"

echo "✅ Installation complete!"