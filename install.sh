#!/bin/bash
set -e
set -o pipefail
set -u

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root. Try: sudo ./install.sh"
    exit 1
fi

echo "🔄 Updating system packages..."
if ! sudo apt update && sudo apt install -y hostapd dnsmasq nodejs npm git; then
    echo "❌ Failed to update packages. Exiting."
    exit 1
fi

echo "📡 Setting Wi-Fi country to enable wireless functionality..."
sudo raspi-config nonint do_wifi_country US || echo "⚠️ Failed to set Wi-Fi country."

echo "🔓 Unblocking Wi-Fi (rfkill)..."
sudo rfkill unblock wifi || echo "⚠️ Failed to unblock Wi-Fi."

echo "📦 Installing PM2 process manager..."
sudo npm install -g pm2 || { echo "❌ Failed to install PM2. Exiting."; exit 1; }

echo "🚫 Disabling default services..."
sudo systemctl unmask hostapd dnsmasq
sudo systemctl enable hostapd dnsmasq
sudo systemctl restart hostapd dnsmasq || echo "⚠️ Warning: Failed to restart hostapd/dnsmasq."

echo "👤 Ensuring splitflap system user exists and is configured correctly..."
if id "splitflap" &>/dev/null; then
    echo "⚠️ User 'splitflap' already exists. Verifying configuration..."
    
    if [ ! -d "/home/splitflap" ]; then
        echo "🔧 Creating missing home directory for splitflap..."
        sudo mkdir -p /home/splitflap
    fi
    sudo chown -R splitflap:splitflap /home/splitflap
    sudo chmod 755 /home/splitflap
    
    sudo usermod -s /bin/false splitflap
    
else
    echo "➕ Creating splitflap system user..."
    sudo useradd -m -r -s /bin/false splitflap
    sudo chmod 755 /home/splitflap
fi

# Fix npm permissions
echo "🔧 Fixing npm permissions..."
sudo mkdir -p /home/splitflap/.npm
sudo chown -R splitflap:splitflap /home/splitflap/.npm
sudo chmod -R 755 /home/splitflap/.npm

# Allow splitflap user to manage Wi-Fi settings
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
ignore_broadcast_ssid=1
EOF

echo "✅ Enabling and restarting AP services..."
sudo systemctl enable hostapd dnsmasq
sudo systemctl restart hostapd || echo "⚠️ Warning: Failed to restart hostapd."
sudo systemctl restart dnsmasq || echo "⚠️ Warning: Failed to restart dnsmasq."

echo "🛠 Setting up application..."
sudo mkdir -p /opt/splitflap
sudo cp -r . /opt/splitflap
sudo chown -R splitflap:splitflap /opt/splitflap
cd /opt/splitflap

echo "📦 Installing Node.js dependencies..."
if ! sudo -u splitflap /usr/bin/npm install --omit=dev; then
    echo "❌ Failed to install Node.js dependencies. Exiting."
    exit 1
fi

echo "🔄 Configuring PM2 for process management..."

# **Check if SplitFlap is already running in PM2**
if sudo -u splitflap pm2 list | grep -q "splitflap"; then
    echo "⚠️ SplitFlap process already exists in PM2. Restarting..."
    sudo -u splitflap pm2 restart splitflap
else
    echo "🚀 Starting SplitFlap service with PM2..."
    if ! sudo -u splitflap pm2 start /usr/bin/node --name splitflap -- /opt/splitflap/src/server.ts --loader ts-node/esm; then
        echo "❌ Failed to start SplitFlap service with PM2. Exiting."
        exit 1
    fi
fi

# Save PM2 process list
sudo -u splitflap pm2 save

# Setup PM2 to start on boot for the 'splitflap' user
echo "⚙️ Setting up PM2 startup script..."
PM2_STARTUP_CMD=$(sudo -u splitflap pm2 startup systemd -u splitflap --hp /home/splitflap | grep "sudo")
if [[ -z "$PM2_STARTUP_CMD" ]]; then
    echo "❌ Failed to generate PM2 startup command. Exiting."
    exit 1
fi

echo "🔄 Running PM2 startup command..."
bash -c "$PM2_STARTUP_CMD"

# Enable PM2 service
if ! sudo systemctl enable pm2-splitflap; then
    echo "❌ Failed to enable pm2-splitflap service. Exiting."
    exit 1
fi

# Ensure PM2 reloads processes on reboot
echo "@reboot splitflap /usr/local/bin/pm2 resurrect" | sudo tee /etc/cron.d/pm2-resurrect > /dev/null
sudo chmod 644 /etc/cron.d/pm2-resurrect
sudo chown root:root /etc/cron.d/pm2-resurrect

echo "🚀 PM2 setup complete. The process should persist after reboot."

sleep 3

echo "🔄 Installation complete. Rebooting now..."
sudo reboot || echo "❌ Failed to reboot. Please manually reboot the system."