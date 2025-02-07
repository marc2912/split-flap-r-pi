#!/usr/bin/env bash

set -

targetConnection="wlan1"

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

LOG_FILE="$HOME/split-flap-r-pi/splitflap_broadcast.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# 1. Install Avahi
echo -e "${BLUE_CUSTOM}🔄 Installing Avahi...${NC}"
sudo apt-get install -y avahi-daemon

# 2. Set the hostname to 'splitflapcontroller'
echo -e "${BLUE_CUSTOM}Setting hostname.${NC}"
sudo hostnamectl set-hostname splitflapcontroller

# 3. Update /etc/hosts so 'splitflapcontroller' resolves properly to 127.0.1.1
if grep -q "splitflapcontroller" /etc/hosts; then
  sudo sed -i 's/^127\.0\.1\.1\s\+.*/127.0.1.1       splitflapcontroller/' /etc/hosts
else
  echo "127.0.1.1       splitflapcontroller" | sudo tee -a /etc/hosts
fi

# 4. Create an Avahi service file to advertise your REST API on port 3000
echo -e "${BLUE_CUSTOM}Creating configuration file${NC}"
cat <<EOF | sudo tee /etc/avahi/services/splitflap.service
<service-group>
  <name replace-wildcards="yes">Splitflap REST API</name>
  <service>
    <type>_http._tcp</type>
    <port>3000</port>
  </service>
</service-group>
EOF

# 5. Configure Avahi to only broadcast on wlan1
# Remove any existing allow-interfaces lines
echo -e "${BLUE_CUSTOM}Locking Avahi to wlan1, to change this change targetConnection value in the broadcast script.${NC}"
sudo sed -i '/^allow-interfaces=/d' /etc/avahi/avahi-daemon.conf
# Insert allow-interfaces=wlan1 under the [server] section
sudo sed -i "/^\[server\]/a allow-interfaces=${targetConnection}" /etc/avahi/avahi-daemon.conf

# 6. Enable and restart Avahi
echo -e "${BLUE_CUSTOM}Restarting the service for changes to take effect.${NC}"
sudo systemctl enable avahi-daemon
sudo systemctl restart avahi-daemon

echo "Setup complete."