#!/usr/bin/env bash

set -e

# 1. Install Avahi
sudo apt-get update
sudo apt-get install -y avahi-daemon

# 2. Set the hostname to 'splitflapcontroller'
sudo hostnamectl set-hostname splitflapcontroller

# 3. Update /etc/hosts so 'splitflapcontroller' resolves properly to 127.0.1.1
if grep -q "splitflapcontroller" /etc/hosts; then
  sudo sed -i 's/^127\.0\.1\.1\s\+.*/127.0.1.1       splitflapcontroller/' /etc/hosts
else
  echo "127.0.1.1       splitflapcontroller" | sudo tee -a /etc/hosts
fi

# 4. Create an Avahi service file to advertise your REST API on port 3000
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
sudo sed -i '/^allow-interfaces=/d' /etc/avahi/avahi-daemon.conf
# Insert allow-interfaces=wlan1 under the [server] section
sudo sed -i '/^\[server\]/a allow-interfaces=wlan1' /etc/avahi/avahi-daemon.conf

# 6. Enable and restart Avahi
sudo systemctl enable avahi-daemon
sudo systemctl restart avahi-daemon

echo "Setup complete. You can now reach your Pi at splitflapcontroller.local:3000 (if your REST service is on port 3000)."