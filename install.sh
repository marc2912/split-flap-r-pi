#!/bin/bash
# TODO : switch to a process manager like pm2 to manage the node process and restart it if it crashes
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Try: sudo ./install.sh"
    exit 1
fi

echo "Installing system dependencies..."
sudo apt update && sudo apt install -y hostapd dnsmasq nodejs npm

echo "Disabling default services..."
sudo systemctl disable hostapd dnsmasq

echo "Creating splitflap system user..."
sudo useradd -r -s /bin/false splitflap

# Grant splitflap user permission to run necessary sudo commands without a password
echo "splitflap ALL=(ALL) NOPASSWD: /bin/cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf, /sbin/wpa_cli -i wlan0 reconfigure" | sudo tee -a /etc/sudoers.d/splitflap

# Configure AP mode
echo "Configuring Wi-Fi Access Point..."
cat <<EOF | sudo tee /etc/hostapd/hostapd.conf
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

# Enable and start hostapd and dnsmasq services
sudo systemctl enable hostapd
echo "AP configuration complete."

# Setting up application
echo "Setting up application..."
sudo mkdir -p /opt/splitflap
sudo cp -r . /opt/splitflap
sudo chown -R splitflap:splitflap /opt/splitflap
cd /opt/splitflap

echo "Installing Node.js dependencies..."
sudo -u splitflap /usr/bin/npm install --production

echo "Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/splitflap.service
[Unit]
Description=Split Flap Controller
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/splitflap/index.js
Restart=always
User=splitflap
WorkingDirectory=/opt/splitflap
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling and starting service..."
sudo systemctl enable splitflap.service
sudo systemctl start splitflap.service

echo "Installation complete. Rebooting now..."
sudo reboot