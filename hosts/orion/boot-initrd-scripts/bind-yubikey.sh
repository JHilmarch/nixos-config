#!/bin/sh
echo "Usage: $0 <busid>"
if [ -z "$1" ]; then
  BUSID=$(sh "$(dirname "$0")/detect-yubikey.sh") || exit 1
else
  BUSID="$1"
fi

echo "Binding YubiKey on bus $BUSID..."
modprobe usbip-host
systemctl enable --now usbipd
usbip bind -b "$BUSID"
exit 0
