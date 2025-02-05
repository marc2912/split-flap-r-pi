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

# Create splitflap user if it doesn’t exist
if ! id "splitflap" &>/dev/null; then
    echo "➕ Creating 'splitflap' system user..."
    useradd -m -r -s /bin/bash splitflap
else
    echo "⚠️ User 'splitflap' already exists."
fi

# Set ownership and permissions for /opt/splitflap
echo "🔧 Setting permissions for /opt/splitflap..."
chown -R splitflap:splitflap /opt/splitflap
chmod -R 755 /opt/splitflap

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
sudo -u splitflap npm install --omit=dev --prefix /opt/splitflap

# Compile TypeScript
echo "🔧 Compiling TypeScript..."
sudo -u splitflap npm run build --prefix /opt/splitflap

# Start the application in the foreground
echo "🚀 Starting SplitFlap..."
exec sudo -u splitflap node /opt/splitflap/dist/server.js