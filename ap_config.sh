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
retry sudo apt install -y net-tools

# Enable & Restart NetworkManager
echo -e "${BLUE_CUSTOM}Enabling NetworkManager...${NC}"
retry sudo systemctl enable NetworkManager
retry sudo systemctl restart NetworkManager
sleep 2  # Wait a bit before running nmcli to allow NetworkManager to start fully

#Configure Wi-Fi Access Point
echo -e "${BLUE_CUSTOM}Configuring Access Point...${NC}"
if nmcli connection show SplitFlap &>/dev/null; then
    echo -e "${BLUE_CUSTOM}Removing old SplitFlap connection...${NC}"
    sudo nmcli connection delete SplitFlap
fi

echo -e "${BLUE_CUSTOM}Creating new AP configuration...${NC}"
sudo nmcli connection add type wifi ifname wlan0 con-name SplitFlap autoconnect yes ssid SplitFlap || true
sudo nmcli connection modify SplitFlap 802-11-wireless.mode ap
sudo nmcli connection modify SplitFlap 802-11-wireless.band bg
sudo nmcli connection modify SplitFlap ipv4.method shared
sudo nmcli connection modify SplitFlap 802-11-wireless-security.proto rsn
sudo nmcli connection modify SplitFlap 802-11-wireless-security.key-mgmt wpa-psk
sudo nmcli connection modify SplitFlap 802-11-wireless-security.psk "opensource"
sudo nmcli connection modify SplitFlap ipv4.addresses 10.42.0.1/24
sudo nmcli connection modify SplitFlap ipv4.gateway 10.42.0.1
sudo nmcli connection modify SplitFlap ipv4.dns 10.42.0.1,8.8.8.8

# Restart NetworkManager
echo -e "${BLUE_CUSTOM}Restarting NetworkManager...${NC}"
sudo systemctl restart NetworkManager

# # setup DHCP server
# echo -e "${BLUE_CUSTOM}Setting up DHCP Server.${NC}"
# DNSMASQ_CONF_PATH="/etc/dnsmasq.conf"

# sudo apt install -y dnsmasq
# sudo rm /etc/dnsmasq.conf

# cat <<EOF > "$DNSMASQ_CONF_PATH"
# # Use wlan0 as the interface for DHCP and DNS services
# interface=wlan0
# bind-interfaces

# # DHCP Range (assigns IPs from 10.42.0.50 to 10.42.0.150)
# dhcp-range=10.42.0.50,10.42.0.150,255.255.255.0,24h

# # Set the default gateway to the Raspberry Pi
# dhcp-option=3,10.42.0.1

# # Set the DNS server (Pi itself, fallback to Google & Cloudflare)
# dhcp-option=6,10.42.0.1,8.8.8.8,1.1.1.1

# # Log DHCP requests (helpful for debugging)
# log-dhcp

# # Prevent DNS from forwarding .local domains (used for local networking)
# domain-needed
# bogus-priv

# # Use Pi as a DNS cache
# cache-size=500

# # Only listen for DHCP and DNS requests on wlan0
# listen-address=10.42.0.1
# EOF

# echo -e "${BLUE_CUSTOM}Restarting the DHCP Server.${NC}"
# retry sudo systemctl restart dnsmasq
# retry sudo systemctl enable dnsmasq

# Verify AP Setup
echo -e "${BLUE_CUSTOM}Access Point Setup Complete!${NC}"
