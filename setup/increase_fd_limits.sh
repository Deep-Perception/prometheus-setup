#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Use sudo."
  exit 1
fi

# Set soft and hard limits
SOFT_LIMIT=65535
HARD_LIMIT=65535

echo "Updating ulimits for the current session..."
ulimit -n $SOFT_LIMIT

echo "Updating /etc/security/limits.conf..."
cat <<EOL >> /etc/security/limits.conf

# Increased limits for all users
* soft nofile $SOFT_LIMIT
* hard nofile $HARD_LIMIT
EOL

echo "Updating PAM limits..."
if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
  echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive; then
  echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
fi

echo "Updating /etc/systemd/system.conf..."
sed -i '/^#DefaultLimitNOFILE/c\DefaultLimitNOFILE='$SOFT_LIMIT':'$HARD_LIMIT /etc/systemd/system.conf

echo "Updating /etc/systemd/user.conf..."
sed -i '/^#DefaultLimitNOFILE/c\DefaultLimitNOFILE='$SOFT_LIMIT':'$HARD_LIMIT /etc/systemd/user.conf

echo "Reloading systemd configuration..."
systemctl daemon-reexec

echo "Changes applied successfully! Please log out and log back in for the changes to take effect."
