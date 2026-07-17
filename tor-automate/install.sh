#!/usr/bin/env bash

set -e

REPO="https://raw.githubusercontent.com/petrovveaceslav43-pixel/tor-automate/main/tor-automate"

echo "========================================"
echo "     Tor Automate Engine Installer"
echo "========================================"

apt-get update
apt-get install -y tor socat curl

curl -fsSL "$REPO/tor-automate.sh" -o /usr/local/bin/tor-automate

chmod +x /usr/local/bin/tor-automate

echo
echo "========================================"
echo " Installation Complete!"
echo "========================================"
echo
echo "Run the program using:"
echo
echo "tor-automate"
echo