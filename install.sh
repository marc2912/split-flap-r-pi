#!/bin/bash
set -e  # Exit immediately on any error

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Try: sudo ./install.sh"
    exit 1
fi

echo "Updating system packages..."
sudo apt update && sudo apt install -y hostapd dnsmasq nodejs npm git

echo "Setting Wi-Fi country to enable wireless functionality..."
sudo raspi-config nonint do_wifi_country US  # Change 'US' if needed

echo "Unblocking Wi-Fi (rfkill)..."
sudo rfkill unblock wifi

echo "Installing PM2 process manager..."
sudo npm install -g pm2

echo "Disabling default services..."
sudo systemctl unmask hostapd dnsmasq
sudo systemctl enable hostapd dnsmasq
sudo systemctl restart hostapd dnsmasq

echo "Creating splitflap system user..."
sudo useradd -r -s /bin/false splitflap

# Allow the splitflap user to manage Wi-Fi settings
echo "splitflap ALL=(ALL) NOPASSWD: /bin/cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf, /sbin/wpa_cli -i wlan0 reconfigure" | sudo tee /etc/sudoers.d/splitflap

echo "Configuring Wi-Fi Access Point..."
sudo mkdir -p /etc/hostapd
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

echo "Enabling and starting AP services..."
sudo systemctl enable hostapd dnsmasq
sudo systemctl restart hostapd dnsmasq

echo "Setting up application..."
sudo mkdir -p /opt/splitflap
sudo cp -r . /opt/splitflap
sudo chown -R splitflap:splitflap /opt/splitflap
cd /opt/splitflap

echo "Installing Node.js dependencies..."
sudo -u splitflap /usr/bin/npm install --production

echo "Configuring PM2 for process management..."
sudo -u splitflap pm2 start /usr/bin/node --name splitflap -- /opt/splitflap/src/server.ts --loader ts-node/esm
sudo -u splitflap pm2 save
sudo -u splitflap pm2 startup systemd | sudo tee /etc/systemd/system/splitflap_pm2.service

echo "Enabling and starting service..."
sudo systemctl enable splitflap_pm2.service
sudo systemctl start splitflap_pm2.service

echo "Installation complete. Rebooting now..."
sudo reboot