#!/bin/sh
HOST="${1:-localhost}"

if [ -z "$2" ]; then
	echo "Usage: $0 <host> <deviceid>"
	echo "'sudo usbip list -r $HOST' to locate YubiKey"
	echo "Trying to autodetect Yubikey..."
	DEVICEID=$(usbip list -r "$HOST" | awk '/1050/ {print $1}' | sed 's/://')
	if [ -n "$DEVICEID" ]; then
		echo "YubiKey found on $HOST:$DEVICEID"
	else
		echo "No YubiKey detected. Exiting..."
		exit 1
	fi
else
	DEVICEID="$2"
fi

echo "Attaching YubiKey on $HOST:$DEVICEID..."
modprobe vhci_hcd
usbip attach -r "$HOST" -d "$DEVICEID"
exit 0
