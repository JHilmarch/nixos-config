#!/bin/sh
echo ""
echo "Welcome to initrd Secure Shell on Orion!"
echo ""
echo "On your local client run"
echo "1. 'sudo sh ~/.ssh/bind-yubikey.sh'"
echo ""
echo "On orion SSH run:"
echo "1. 'attach-yubikey'"
echo "2. 'unlock'"
echo ""
exec /bin/sh
exit 0
