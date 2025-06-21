#!/bin/sh
if [ -z "$1" ]; then
  if ! BUSID=$(sh "$(dirname "$0")/detect-yubikey.sh"); then
    exit 1
  fi
else
  BUSID="$1"
fi

echo "Binding YubiKey on bus $BUSID..."
modprobe usbip-host
usbip bind -b "$BUSID"
exit 0
