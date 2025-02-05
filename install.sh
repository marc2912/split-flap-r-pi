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

# Install Node.js v22.x from NodeSource
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

# Configure npm global directory
echo "🔧 Configuring npm global directory..."
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"

# Ensure PATH is updated for npm binaries
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.profile"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bash_profile"
export PATH="$HOME/.npm-global/bin:$PATH"

# Source updated profile settings
source "$HOME/.bashrc"
source "$HOME/.profile"

# Install PM2 globally
echo "📦 Installing PM2..."
npm install -g pm2

# Ensure PM2 is properly installed and available
if ! command -v pm2 &>/dev/null; then
    echo "❌ PM2 installation failed. Exiting."
    exit 1
fi

# Set up PM2 to start on boot
echo "🔄 Configuring PM2 for auto-start..."
eval "$(pm2 startup systemd -u "$(whoami)" --hp "$HOME" | tail -n 1)"

# Start SplitFlap with PM2
echo "🚀 Starting SplitFlap with PM2..."
pm2 start "$HOME/split-flap-r-pi/dist/server.js" --name splitflap

# Save PM2 process list
echo "💾 Saving PM2 process list..."
pm2 save

# Enable PM2 service (user-level)
echo "🔄 Enabling PM2 service..."
systemctl --user enable pm2-$(whoami)
systemctl --user restart pm2-$(whoami)

echo "✅ Installation complete!"