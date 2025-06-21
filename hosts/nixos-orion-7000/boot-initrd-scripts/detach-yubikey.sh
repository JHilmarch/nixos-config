#!/bin/sh
if [ -z "$1" ]; then
	echo "Usage: $0 <usb-port>"
	echo "'sudo usbip list -r <host>' or 'usbip port' to locate YubiKey"
	echo "Trying to autodetect Yubikey..."
	PORT=$(usbip port | awk '/1050/ {print port} {if($1=="Port") port=$2}' | sed 's/://')
	if [ -n "$PORT" ]; then
		echo "YubiKey found on port $PORT"
	else
		echo "No YubiKey detected. Exiting..."
		exit 1
	fi
else
	PORT="$1"
fi

echo "Detaching YubiKey on port $PORT..."
usbip detach -p "$PORT"
exit 0
