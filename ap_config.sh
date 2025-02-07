#!/bin/bash

set -e
set -o pipefail
set -u

# Reset color
NC='\033[0m'  
# Check for true color support
if [[ "${COLORTERM:-}" == "truecolor" || "${COLORTERM:-}" == "24bit" ]]; then
    BLUE_CUSTOM='\033[38;2;47;98;155m'  # Exact #2F629B in true color
elif [[ "$TERM" =~ "256color" ]]; then
    BLUE_CUSTOM='\033[38;5;61m'  # Approximate color for 256-color mode
else
    BLUE_CUSTOM='\033[0m'  # No color support, fallback to default terminal text
fi

LOG_FILE="$HOME/splitflap_ap_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${BLUE_CUSTOM}🔄 Starting Access Point Setup...${NC}"

# Ensure Not Running as Root
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${BLUE_CUSTOM}❌ Do NOT run this script as root! Run it as a normal user.${NC}"
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
                echo -e "${BLUE_CUSTOM}⚠️ Command failed. Attempt $n/$max: $@${NC}"
                sleep $delay;
            else
                echo -e "${BLUE_CUSTOM}❌ Command failed after $max attempts: $@${NC}"
                exit 1
            fi
        }
    done
}

# Set Wi-Fi Country
echo -e "${BLUE_CUSTOM}Setting Wi-Fi Country...${NC}"
retry sudo raspi-config nonint do_wifi_country US

# Unblock Wi-Fi
echo -e "${BLUE_CUSTOM}Unblocking Wi-Fi...${NC}"
sudo rfkill unblock wifi

# Install NetworkManager
echo -e "${BLUE_CUSTOM}Installing NetworkManager...${NC}"
retry sudo apt-get update
retry sudo apt-get install -y network-manager

# Enable & Restart NetworkManager
echo -e "${BLUE_CUSTOM}Enabling NetworkManager...${NC}"
retry sudo systemctl enable NetworkManager
retry sudo systemctl restart NetworkManager
sleep 2  # Wait a bit before running nmcli to allow NetworkManager to start fully

#Configure Wi-Fi Access Point
echo -e "${BLUE_CUSTOM}Configuring Access Point...${NC}"
if nmcli connection show SplitFlap &>/dev/null; then
    echo -e "${BLUE_CUSTOM}Updating existing AP configuration...${NC}"
    sudo nmcli connection modify SplitFlap 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
    sudo nmcli connection modify SplitFlap wifi-sec.key-mgmt wpa-psk
    sudo nmcli connection modify SplitFlap wifi-sec.psk "opensource"
else
    echo -e "${BLUE_CUSTOM}Creating new AP configuration...${NC}"
    sudo nmcli connection add type wifi ifname wlan0 con-name SplitFlap autoconnect yes ssid SplitFlap
    sudo nmcli connection modify SplitFlap 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
    sudo nmcli connection modify SplitFlap wifi-sec.key-mgmt wpa-psk
    sudo nmcli connection modify SplitFlap wifi-sec.psk "opensource"
fi
# Restart NetworkManager
echo -e "${BLUE_CUSTOM}Restarting NetworkManager...${NC}"
sudo systemctl restart NetworkManager

# Verify AP Setup
echo -e "${BLUE_CUSTOM}Access Point Setup Complete!${NC}"
echo -e "${BLUE_CUSTOM}Press enter to reboot the system and apply changes.${NC}"
read -p ">"
echo -e "${BLUE_CUSTOM}🔄 Rebooting to apply changes...${NC}"
sleep 2
sudo reboot