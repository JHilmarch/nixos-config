#!/bin/sh
echo "Usage: $0 <busid>"
if [ -z "$1" ]; then
  BUSID=$(detect-yubikey) || exit 1
else
  BUSID="$1"
fi

echo "Unbinding YubiKey on bus $BUSID..."
usbip unbind -b "$BUSID"
exit 0
