#!/bin/sh
echo "Usage: $0 <busid>" >&2
echo "'sudo usbip list -l' to locate YubiKey" >&2
echo "Trying to autodetect YubiKey..." >&2
BUSID=$(usbip list -l | grep -Ei -B1 '1050' | grep 'busid' | awk '{print $3}')
if [ -n "$BUSID" ]; then
    echo "$BUSID"
    exit 0
else
    echo "No YubiKey detected. Exiting..." >&2
    exit 1
fi
