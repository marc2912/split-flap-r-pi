#!/bin/bash

set -e
set -o pipefail
set -u

# Define the path to the NetworkManager config file
CONFIG_PATH="/etc/NetworkManager/system-connections/SplitFlap.nmconnection"

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
retry sudo apt-get install -y net-tools

# Enable & Restart NetworkManager
echo -e "${BLUE_CUSTOM}Enabling NetworkManager...${NC}"
retry sudo systemctl enable NetworkManager
retry sudo systemctl restart NetworkManager
sleep 2  # Wait a bit before running nmcli to allow NetworkManager to start fully

#Configure Wi-Fi Access Point
echo -e "${BLUE_CUSTOM}Configuring Access Point...${NC}"
if nmcli connection show SplitFlap &>/dev/null; then
    echo -e "${BLUE_CUSTOM}Old AP found, removing it...${NC}"
    sudo nmcli connection delete SplitFlap
fi

echo -e "${BLUE_CUSTOM}Creating new AP configuration...${NC}"
sudo bash -c "cat > $CONFIG_PATH" <<EOF
[connection]
id=SplitFlap
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
band=bg
mode=ap
ssid=SplitFlap

[wifi-security]
key-mgmt=wpa-psk
proto=rsn
psk=opensource

[ipv4]
address1=10.42.0.1/24,10.42.0.1
method=shared

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
EOF

sudo chmod 600 "$CONFIG_PATH"

# Restart NetworkManager
echo -e "${BLUE_CUSTOM}Restarting NetworkManager...${NC}"
retry sudo systemctl restart NetworkManager

# Verify AP Setup
# Verify that the AP is active
echo "📡 Checking if SplitFlap AP is running..."
sleep 5
retry nmcli connection show --active | grep SplitFlap

echo -e "${BLUE_CUSTOM}Access Point Setup Complete!${NC}"
