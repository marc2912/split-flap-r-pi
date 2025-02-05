#!/bin/bash

set -e
set -o pipefail
set -u

LOG_FILE="/var/log/splitflap_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔄 Starting SplitFlap installation..."

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root. Try: sudo ./install.sh"
    exit 1
fi

# Get the username of the non-root user running the script
USERNAME="$(logname)"

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
retry apt-get update
retry apt-get upgrade -y

# Install dependencies
echo "📦 Installing required dependencies..."
retry apt-get install -y curl

# Install Node.js v22.13.1 from NodeSource
echo "🔧 Installing Node.js v22.13.1..."
retry curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
retry apt-get install -y nodejs

# Verify Node.js version
echo "✅ Node.js version: $(node -v)"

# Ensure /opt/splitflap exists and set correct permissions
echo "📂 Ensuring correct permissions for /opt/splitflap..."
mkdir -p /opt/splitflap
chown -R "$USERNAME":"$USERNAME" /opt/splitflap
chmod -R 755 /opt/splitflap

# Move into /opt/splitflap
cd /opt/splitflap

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
sudo -u "$USERNAME" npm install --omit=dev

# Compile TypeScript
echo "🔧 Compiling TypeScript..."
sudo -u "$USERNAME" npm run build

# Install PM2 **as the user, NOT root**
echo "📦 Installing PM2..."
sudo -u "$USERNAME" npm install -g pm2

# Ensure PM2 starts on boot **for the user**
echo "🔄 Setting up PM2 for $USERNAME..."
sudo -u "$USERNAME" pm2 startup systemd --hp "/home/$USERNAME"

# Start SplitFlap with PM2
echo "🚀 Starting SplitFlap with PM2 as $USERNAME..."
sudo -u "$USERNAME" pm2 start /opt/splitflap/dist/server.js --name splitflap

# Save PM2 process list **under the correct user**
echo "💾 Saving PM2 process list..."
sudo -u "$USERNAME" pm2 save

# Enable PM2 service to start on boot
echo "🔄 Enabling PM2 service..."
sudo systemctl enable pm2-"$USERNAME"
sudo systemctl restart pm2-"$USERNAME"

echo "✅ Installation complete!"