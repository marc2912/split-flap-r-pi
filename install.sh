#!/bin/bash

set -e
set -o pipefail
set -u

LOG_FILE="$HOME/split-flap-r-pi/splitflap_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# 🔥 Prevent running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "❌ This script should NOT be run as root! Run it as your normal user."
    exit 1
fi

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

# 🔥 Step 1: Prompt user to manually update the system
echo "⚠️  Please run the following commands manually before proceeding:"
echo "    sudo apt-get update && sudo apt-get upgrade -y"
echo "    sudo apt-get install -y curl"
read -p "Press Enter to continue once these steps are complete..."

# 🔥 Step 2: Install Node.js 22.x
echo "🔧 Installing Node.js v22.x..."
retry sudo apt-get remove --purge -y nodejs
retry curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
retry sudo apt-get install -y nodejs

# 🔥 Step 3: Verify Node.js version
echo "✅ Node.js version: $(node -v)"

# 🔥 Step 4: Set correct permissions for the project folder
chmod -R 755 "$HOME/split-flap-r-pi"

# 🔥 Step 5: Move into the SplitFlap project directory
cd "$HOME/split-flap-r-pi"

# 🔥 Step 6: Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install --omit=dev

# 🔥 Step 7: Compile TypeScript
echo "🔧 Compiling TypeScript..."
npm run build

# 🔥 Step 8: Configure npm global directory
echo "🔧 Configuring npm global directory..."
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"

# 🔥 Step 9: Ensure PATH is updated for npm binaries
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.profile"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bash_profile"
export PATH="$HOME/.npm-global/bin:$PATH"

# 🔥 Step 10: Install PM2 globally (user-level)
echo "📦 Installing PM2..."
npm install -g pm2

# 🔥 Step 11: Ensure PM2 is properly installed
if ! command -v pm2 &>/dev/null; then
    echo "❌ PM2 installation failed. Exiting."
    exit 1
fi

# 🔥 Step 12: Enable `linger` to allow user services after reboot
echo "🔄 Enabling user services to persist after logout..."
loginctl enable-linger "$(whoami)"

# 🔥 Step 13: Create a systemd service file
SERVICE_PATH="$HOME/.config/systemd/user/splitflap.service"

echo "🔧 Creating systemd service..."
mkdir -p "$HOME/.config/systemd/user"

cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=SplitFlap Display Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$HOME/split-flap-r-pi
ExecStart=$(which node) $HOME/split-flap-r-pi/dist/server.js
Restart=always
Environment=PATH=$HOME/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=NODE_ENV=production

[Install]
WantedBy=default.target
EOF

# 🔥 Step 14: Reload systemd and enable service
echo "🔄 Enabling SplitFlap service..."
systemctl --user daemon-reload
systemctl --user enable splitflap.service
systemctl --user restart splitflap.service

echo "✅ Installation complete!"
echo "👉 To check logs: journalctl --user -xeu splitflap.service --no-pager | tail -50"
echo "👉 To restart manually: systemctl --user restart splitflap.service"
echo "👉 To stop manually: systemctl --user stop splitflap.service"