#!/usr/bin/env bash

set -e

# 1. Install Avahi
sudo apt-get update
sudo apt-get install -y avahi-daemon

# 2. Set the hostname to 'splitflapcontroller'
sudo hostnamectl set-hostname splitflapcontroller

# Update /etc/hosts so 'splitflapcontroller' resolves properly to 127.0.1.1
sudo sed -i 's/127.0.1.1.*/127.0.1.1       splitflapcontroller/g' /etc/hosts

# 3. Create an Avahi service file to advertise HTTP on port 8080
cat <<EOF | sudo tee /etc/avahi/services/splitflap.service
<service-group>
  <name replace-wildcards="yes">Splitflap HTTP</name>
  <service>
    <type>_http._tcp</type>
    <port>8080</port>
  </service>
</service-group>
EOF

# Enable and restart Avahi
sudo systemctl enable avahi-daemon
sudo systemctl restart avahi-daemon

echo "Setup complete. You can now reach your Pi at http://splitflapcontroller.local:8080 (if your REST service is on port 8080)."