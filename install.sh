#!/bin/bash

set -e
set -o pipefail
set -u


# Reset color
NC='\033[0m'  
# Check for true color support
if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
    BLUE_CUSTOM='\033[38;2;47;98;155m'  # Exact #2F629B in true color
elif [[ "$TERM" =~ "256color" ]]; then
    BLUE_CUSTOM='\033[38;5;61m'  # Approximate color for 256-color mode
else
    BLUE_CUSTOM='\033[0m'  # No color support, fallback to default terminal text
fi



LOG_FILE="$HOME/split-flap-r-pi/splitflap_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Prevent running as root
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${BLUE_CUSTOM}❌ This script should NOT be run as root! Run it as your normal user.${NC}"
    exit 1
fi


echo -e "${BLUE_CUSTOM} 🔄 Starting SplitFlap installation...${NC}"

# Function to retry commands
retry() {
    local n=1
    local max=3
    local delay=5
    while true; do
        "$@" && break || {
            if [[ $n -lt $max ]]; then
                ((n++))
                echo -e "${BLUE_CUSTOM}Command failed. Attempt $n/$max: $@${NC}"
                sleep $delay;
            else
                echo -e "${BLUE_CUSTOM}❌ Command failed after $max attempts: $@${NC}"
                exit 1
            fi
        }
    done
}

# update the system
echo -e "${BLUE_CUSTOM}🔧 Running updates first, this might take a while...${NC}"
echo -e "${BLUE_CUSTOM}Press enter to continue${NC}"
read -p ">"
retry sudo bash -c "apt-get update && apt-get upgrade -y"
retry sudo apt-get install -y curl

# install Node.js 22.x
echo -e "${BLUE_CUSTOM}🔧 Installing Node.js v22.x...${NC}"
retry sudo apt-get remove --purge -y nodejs
retry curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
retry sudo apt-get install -y nodejs

# verify Node.js version
echo -e "${BLUE_CUSTOM}Node.js version: $(node -v)${NC}"

# set correct permissions for the project folder
chmod -R 755 "$HOME/split-flap-r-pi"

# move into the SplitFlap project directory
cd "$HOME/split-flap-r-pi"

# Install Node.js dependencies
echo -e "${BLUE_CUSTOM}Installing Node.js dependencies...${NC}"
npm install --omit=dev

# Compile TypeScript
echo -e "${BLUE_CUSTOM}Compiling TypeScript...${NC}"
npm run build

# Configure npm global directory
echo -e "${BLUE_CUSTOM}configuring npm global directory...${NC}"
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"

# make sure PATH is updated for npm binaries, required because of the way the npm global directory is configured
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.profile"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bash_profile"
export PATH="$HOME/.npm-global/bin:$PATH"

#  Enable `linger` to allow user services after reboot
echo -e "${BLUE_CUSTOM}Enabling user services to persist after logout...${NC}"
loginctl enable-linger "$(whoami)"

# create a systemd service file
SERVICE_PATH="$HOME/.config/systemd/user/splitflap.service"

echo -e "${BLUE_CUSTOM}Creating systemd service...${NC}"
mkdir -p "$HOME/.config/systemd/user"

cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=SplitFlap Display Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$HOME/split-flap-r-pi
ExecStart=/usr/bin/env node $HOME/split-flap-r-pi/dist/server.js
Restart=always
Environment=PATH=$HOME/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=NODE_ENV=production

[Install]
WantedBy=default.target
EOF

# Reload systemd and enable service
echo -e "${BLUE_CUSTOM}Enabling SplitFlap service...${NC}"
systemctl --user daemon-reload
systemctl --user enable splitflap.service
systemctl --user restart splitflap.service

echo -e "${BLUE_CUSTOM}✅ Installation complete!${NC}"
echo -e "${BLUE_CUSTOM}👉 To check logs: journalctl --user -xeu splitflap.service --no-pager | tail -50${NC}"
echo -e "${BLUE_CUSTOM}👉 To restart manually: systemctl --user restart splitflap.service${NC}"
echo -e "${BLUE_CUSTOM}👉 To stop manually: systemctl --user stop splitflap.service${NC}"

# Start the access point configuration script
echo -e "${BLUE_CUSTOM}The application is now installed and running as a service.${NC}"
echo -e "${BLUE_CUSTOM}Next we need to setup the Pi as an access point, this script will be launched${NC}"
echo -e "${BLUE_CUSTOM}by executing the following script: ./ap_config.sh${NC}"
echo -e "${BLUE_CUSTOM}Press enter to start the access point configuration script${NC}"
read -p ">"

if [ -f "./ap_config.sh" ]; then
    chmod +x ./ap_config.sh
    ./ap_config.sh
else
    echo -e "${BLUE_CUSTOM}ERROR: Access Point setup script 'ap_config.sh' not found.${NC}"
    echo -e "${BLUE_CUSTOM}This script is required to configure the access point.${NC}"
fi
