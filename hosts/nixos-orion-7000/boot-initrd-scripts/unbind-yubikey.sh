#!/bin/sh
if [ -z "$1" ]; then
	echo "Usage: $0 <busid>"
	echo "'sudo usbip list -l' to locate YubiKey"
	echo "Trying to autodetect Yubikey..."
	BUSID=$(usbip list -l | grep -Ei -B1 '1050' | grep 'busid' | awk '{print $3}')
	if [ -n "$BUSID" ]; then
		echo "YubiKey found on bus $BUSID"
	else
		echo "No YubiKey detected. Exiting..."
		exit 1
	fi
else
	BUSID="$1"
fi

echo "Unbinding YubiKey on bus $BUSID..."
usbip unbind -b "$BUSID"
exit 0
