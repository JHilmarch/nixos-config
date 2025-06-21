#!/bin/sh
if [ -z "$1" ]; then
	echo "Usage: $0 <usb-port>"
	echo "'sudo usbip list -r <host>' or 'usbip port' to locate YubiKey"
	echo "Trying to autodetect Yubikey..."
	# Attempt to autodetect the YubiKey by parsing the output of 'usbip port'
	# 1. Look for lines containing '1050' (YubiKey vendor ID).
	# 2. Extract the port number from the preceding 'Port' line.
	# 3. Remove the trailing colon from the port number.
	PORT=$(usbip port | awk '
		$1 == "Port" { port = $2 }  # Save the port number when "Port" is found
		/1050/ { print port }       # Print the saved port number if "1050" is found
	' | sed 's/://')
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
