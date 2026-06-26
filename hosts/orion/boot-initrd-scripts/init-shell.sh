#!/bin/sh
echo ""
echo "Welcome to initrd Secure Shell on Orion!"
echo ""
echo "On your local client run"
echo "1. 'sudo bind-yubikey'"
echo ""
echo "On orion SSH run:"
echo "1. 'attach-yubikey'"
echo "2. 'unlock'"
echo ""
echo "See scripts/yubikey-usbip/README.md for the full flow."
exec /bin/sh
exit 0
