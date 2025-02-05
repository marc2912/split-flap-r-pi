#!/bin/bash

set -e
set -o pipefail
set -u

LOG_FILE="$HOME/split-flap-r-pi/splitflap_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔄 Starting SplitFlap installation..."

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

# Prompt user to manually run required system updates
echo "⚠️  Please run the following commands manually before proceeding:"
echo "    sudo apt-get update && sudo apt-get upgrade -y"
echo "    sudo apt-get install -y curl"
read -p "Press Enter to continue once these steps are complete..."

# Install Node.js v22.13.1 from NodeSource
echo "🔧 Ensuring Node.js 22.x is installed..."
sudo apt-get remove --purge -y nodejs
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt-get install -y nodejs

# Verify Node.js version
echo "✅ Node.js version: $(node -v)"

chmod -R 755 "$HOME/split-flap-r-pi"

# Move into SplitFlap directory
cd "$HOME/split-flap-r-pi"

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install --omit=dev

# Compile TypeScript
echo "🔧 Compiling TypeScript..."
npm run build

# Install PM2 globally (user-level)
echo "📦 Installing PM2..."
npm install -g pm2

# Set up PM2 to start on boot
echo "🔄 Configuring PM2 for auto-start..."
pm2 startup systemd -u "$(whoami)" --hp "$HOME"

# Start SplitFlap with PM2
echo "🚀 Starting SplitFlap with PM2..."
pm2 start "$HOME/split-flap-r-pi/dist/server.js" --name splitflap

# Save PM2 process list to ensure auto-restart on boot
echo "💾 Saving PM2 process list..."
pm2 save

# Enable PM2 service to start on boot
echo "🔄 Enabling PM2 service..."
systemctl enable "pm2-$(whoami)"
systemctl restart "pm2-$(whoami)"

echo "✅ Installation complete!"