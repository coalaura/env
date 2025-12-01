#!/bin/bash

set -euo pipefail

echo "Linking sysusers config..."

mkdir -p /etc/sysusers.d

if [ ! -f /etc/sysusers.d/[name].conf ]; then
    ln -s "[path]/conf/[name].conf" /etc/sysusers.d/[name].conf
fi

echo "Creating user..."
systemd-sysusers

echo "Linking unit..."
rm /etc/systemd/system/[name].service

systemctl link "[path]/conf/[name].service"

echo "Reloading daemon..."
systemctl daemon-reload
systemctl enable [name]

echo "Fixing initial permissions..."
chown -R [name]:[name] "[path]"

find "[path]" -type d -exec chmod 755 {} +
find "[path]" -type f -exec chmod 644 {} +

chmod +x "[path]/[name]"

echo "Setup complete, starting service..."

service [name] start

echo "Done."
