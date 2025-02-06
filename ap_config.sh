#!/bin/bash

set -e
set -o pipefail
set -u

LOG_FILE="$HOME/splitflap_ap_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔄 Starting Access Point Setup..."

# Ensure Not Running as Root
if [ "$(id -u)" -eq 0 ]; then
    echo "❌ Do NOT run this script as root! Run it as a normal user."
    exit 1
fi

# function to Retry Command
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

# Set Wi-Fi Country
echo "Setting Wi-Fi Country..."
retry sudo raspi-config nonint do_wifi_country US

# Unblock Wi-Fi
echo "Unblocking Wi-Fi..."
sudo rfkill unblock wifi

# Install NetworkManager
echo "Installing NetworkManager..."
retry sudo apt-get update
retry sudo apt-get install -y network-manager

# Enable & Restart NetworkManager
echo "Enabling NetworkManager..."
retry sudo systemctl enable NetworkManager
retry sudo systemctl restart NetworkManager
sleep 2  # Wait a bit before running nmcli to allow NetworkManager to start fully

#Configure Wi-Fi Access Point
echo "Configuring Access Point..."
if nmcli connection show SplitFlap &>/dev/null; then
    echo "Updating existing AP configuration..."
    sudo nmcli connection modify SplitFlap 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
    sudo nmcli connection modify SplitFlap wifi-sec.key-mgmt wpa-psk
    sudo nmcli connection modify SplitFlap wifi-sec.psk "opensource"
else
    echo "Creating new AP configuration..."
    sudo nmcli connection add type wifi ifname wlan0 con-name SplitFlap autoconnect yes ssid SplitFlap
    sudo nmcli connection modify SplitFlap 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
    sudo nmcli connection modify SplitFlap wifi-sec.key-mgmt wpa-psk
    sudo nmcli connection modify SplitFlap wifi-sec.psk "opensource"
fi
# Restart NetworkManager
echo "Restarting NetworkManager..."
sudo systemctl restart NetworkManager

# Verify AP Setup
echo "Access Point Setup Complete!"
echo "Checking active connections:"
sudo nmcli connection up SplitFlap
nmcli connection show --active
echo "Available Wi-Fi networks:"
nmcli device wifi list
echo "✅ AP Installation complete!"