#!/bin/bash

DEBUG=0

while getopts "d" opt; do
  case ${opt} in
    d )
      DEBUG=1
      ;;
    * )
      echo "Usage: sudo ./install.sh [-d]"
      exit 1
      ;;
  esac
done

if [ "$DEBUG" -eq 1 ]; then
  set -x  # Enable debug mode
fi

set -e
set -o pipefail
set -u

LOG_FILE="/var/log/splitflap_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Catch any early exits and log them
trap 'echo "⚠️ Script exited early at line $LINENO with exit code $?"; exit 1' ERR

echo "🔄 Starting SplitFlap installation..."

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

retry sudo apt-get update
retry sudo apt-get upgrade -y
retry sudo apt-get install -y hostapd dnsmasq nodejs npm git curl

sudo raspi-config nonint do_wifi_country US || echo "⚠️ Failed to set Wi-Fi country."
sudo rfkill unblock wifi || echo "⚠️ Failed to unblock Wi-Fi."

retry sudo npm install -g pm2

sudo systemctl unmask hostapd dnsmasq
sudo systemctl enable hostapd dnsmasq
retry sudo systemctl restart hostapd dnsmasq

if ! id "splitflap" &>/dev/null; then
    echo "➕ Creating splitflap system user..."
    sudo useradd -m -r -s /bin/bash splitflap
else
    echo "⚠️ User 'splitflap' already exists. Verifying configuration..."
    sudo usermod -s /bin/bash splitflap
fi

sudo chown -R splitflap:splitflap /home/splitflap
sudo chmod 755 /home/splitflap

# Set up npm for the splitflap user to prevent permission errors
echo "🔧 Configuring npm global directory for splitflap user..."
sudo -u splitflap mkdir -p /home/splitflap/.npm-global
sudo -u splitflap npm config set prefix /home/splitflap/.npm-global

echo 'export PATH=/home/splitflap/.npm-global/bin:$PATH' | sudo tee -a /home/splitflap/.bashrc > /dev/null
sudo -u splitflap bash -c "source /home/splitflap/.bashrc"

# Install ts-node in the user’s npm directory
retry sudo -u splitflap npm install -g ts-node

sudo mkdir -p /home/splitflap/.npm
sudo chown -R splitflap:splitflap /home/splitflap/.npm
sudo chmod -R 755 /home/splitflap/.npm

echo "🔑 Configuring sudo permissions..."
echo "splitflap ALL=(ALL) NOPASSWD: /bin/cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf, /sbin/wpa_cli -i wlan0 reconfigure" | sudo tee /etc/sudoers.d/splitflap > /dev/null

echo "📡 Configuring Wi-Fi Access Point..."
sudo mkdir -p /etc/hostapd
cat <<EOF | sudo tee /etc/hostapd/hostapd.conf > /dev/null
interface=wlan0
driver=nl80211
ssid=splitflap
wpa_passphrase=spl1tfl@p
hw_mode=g
channel=6
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
ignore_broadcast_ssid=0
EOF

retry sudo systemctl restart hostapd
retry sudo systemctl restart dnsmasq

echo "🛠 Setting up application..."
sudo mkdir -p /opt/splitflap
sudo cp -r . /opt/splitflap
sudo chown -R splitflap:splitflap /opt/splitflap
cd /opt/splitflap

retry sudo -u splitflap /usr/bin/npm install --omit=dev

# Ensure PM2 systemd service is properly generated and enabled
echo "🔄 Configuring PM2 to start on boot..."
sudo usermod -s /bin/bash splitflap
retry pm2 startup systemd -u splitflap --hp /home/splitflap

if [ ! -f "/etc/systemd/system/pm2-splitflap.service" ]; then
    echo "⚠️ PM2 systemd service file is missing! Attempting to regenerate..."
    retry pm2 startup systemd -u splitflap --hp /home/splitflap
fi

sudo chmod 644 /etc/systemd/system/pm2-splitflap.service
sudo chown root:root /etc/systemd/system/pm2-splitflap.service

retry sudo systemctl daemon-reload
retry sudo systemctl enable pm2-splitflap
retry sudo systemctl restart pm2-splitflap

# Get the correct ts-node path for the splitflap user
TS_NODE_PATH="/home/splitflap/.npm-global/bin/ts-node"
echo "✅ Using ts-node path: $TS_NODE_PATH"

# Start SplitFlap app in PM2 and ensure persistence
echo "🚀 Starting SplitFlap app with PM2..."
retry sudo -u splitflap env PATH="/home/splitflap/.npm-global/bin:$PATH" pm2 start "$TS_NODE_PATH" --name splitflap -- /opt/splitflap/src/server.ts
retry sudo -u splitflap pm2 save


echo "✅ Script completed successfully. Rebooting now..."
sleep 3
echo "🔄 Installation complete. Rebooting now..."
sudo reboot || echo "❌ Failed to reboot. Please manually reboot the system."
