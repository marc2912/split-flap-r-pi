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
    sudo useradd -m -r -s /bin/false splitflap
else
    echo "⚠️ User 'splitflap' already exists. Verifying configuration..."
fi

sudo chown -R splitflap:splitflap /home/splitflap
sudo chmod 755 /home/splitflap

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
ignore_broadcast_ssid=1
EOF

retry sudo systemctl restart hostapd
retry sudo systemctl restart dnsmasq

echo "🛠 Setting up application..."
sudo mkdir -p /opt/splitflap
sudo cp -r . /opt/splitflap
sudo chown -R splitflap:splitflap /opt/splitflap
cd /opt/splitflap

retry sudo -u splitflap /usr/bin/npm install --omit=dev

if sudo -u splitflap pm2 list | grep -q "splitflap"; then
    echo "⚠️ SplitFlap process already exists in PM2. Restarting..."
    retry sudo -u splitflap pm2 restart splitflap
else
    echo "🚀 Starting SplitFlap service with PM2..."
    retry sudo -u splitflap pm2 start /usr/bin/node --name splitflap -- /opt/splitflap/src/server.ts --loader ts-node/esm
fi

sudo -u splitflap pm2 save

# Ensure PM2 resurrects processes after reboot
echo "🔄 Ensuring PM2 resurrects processes on reboot..."
retry sudo -u splitflap pm2 resurrect
retry sudo -u splitflap pm2 save

retry sudo systemctl enable pm2-splitflap

echo "@reboot splitflap /usr/local/bin/pm2 resurrect" | sudo tee /etc/cron.d/pm2-resurrect > /dev/null
sudo chmod 644 /etc/cron.d/pm2-resurrect
sudo chown root:root /etc/cron.d/pm2-resurrect

echo "🚀 PM2 setup complete. The process should persist after reboot."

sleep 3
echo "🔄 Installation complete. Rebooting now..."
sudo reboot || echo "❌ Failed to reboot. Please manually reboot the system."
