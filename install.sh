#!/bin/bash

set -e
set -o pipefail
set -u

LOG_FILE="$HOME/split-flap-r-pi/splitflap_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Prevent running as root
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

# update the system
echo "🔧 Running updates first, this might take a while..."
read -p "Press Enter to continue."
retry sudo bash -c "apt-get update && apt-get upgrade -y"
retry sudo apt-get install -y curl

# install Node.js 22.x
echo "🔧 Installing Node.js v22.x..."
retry sudo apt-get remove --purge -y nodejs
retry curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
retry sudo apt-get install -y nodejs

# verify Node.js version
echo "Node.js version: $(node -v)"

# set correct permissions for the project folder
chmod -R 755 "$HOME/split-flap-r-pi"

# move into the SplitFlap project directory
cd "$HOME/split-flap-r-pi"

# Install Node.js dependencies
echo "Installing Node.js dependencies..."
npm install --omit=dev

# Compile TypeScript
echo "Compiling TypeScript..."
npm run build

# Configure npm global directory
echo "configuring npm global directory..."
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"

# make sure PATH is updated for npm binaries, required because of the way the npm global directory is configured
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.profile"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bash_profile"
export PATH="$HOME/.npm-global/bin:$PATH"

#  Enable `linger` to allow user services after reboot
echo "Enabling user services to persist after logout..."
loginctl enable-linger "$(whoami)"

# create a systemd service file
SERVICE_PATH="$HOME/.config/systemd/user/splitflap.service"

echo "Creating systemd service..."
mkdir -p "$HOME/.config/systemd/user"

cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=SplitFlap Display Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$HOME/split-flap-r-pi
ExecStart=/usr/bin/env node $HOME/split-flap-r-pi/dist/server.js
Restart=always
Environment=PATH=$HOME/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=NODE_ENV=production

[Install]
WantedBy=default.target
EOF

# Reload systemd and enable service
echo "Enabling SplitFlap service..."
systemctl --user daemon-reload
systemctl --user enable splitflap.service
systemctl --user restart splitflap.service

echo "✅ Installation complete!"
echo "👉 To check logs: journalctl --user -xeu splitflap.service --no-pager | tail -50"
echo "👉 To restart manually: systemctl --user restart splitflap.service"
echo "👉 To stop manually: systemctl --user stop splitflap.service"

# Start the access point configuration script
echo "The application is now installed and running as a service."
echo "Next we need to setup the Pi as an access point, this script will be launched"
echo "by executing the following script: ./ap_config.sh"
read -p "Press enter to start the access point configuration script"

if [ -f "./ap_config.sh" ]; then
    chmod +x ./ap_config.sh
    ./ap_config.sh
else
    echo "ERROR: Access Point setup script (ap_config.sh) not found."
    echo "This script is required to configure the access point."
fi
