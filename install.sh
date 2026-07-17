#!/usr/bin/env bash

set -e

REPO="https://raw.githubusercontent.com/petrovveaceslav43-pixel/tor-automate/main"

echo "========================================"
echo "     Tor Automate Engine Installer"
echo "========================================"

echo "[*] Installing dependencies..."
apt-get update
apt-get install -y tor socat curl

echo "[*] Downloading Tor Automate Engine..."
curl -fsSL "$REPO/tor-automate.sh" -o /usr/local/bin/tor-automate

chmod +x /usr/local/bin/tor-automate

echo
echo "========================================"
echo " Installation Complete!"
echo "========================================"
echo
echo "Run the program using:"
echo "tor-automate"
echo
