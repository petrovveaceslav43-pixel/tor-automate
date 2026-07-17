#!/usr/bin/env bash

set -e

echo "======================================"
echo "      Tor Automate Engine Installer"
echo "======================================"

apt update

apt install -y tor socat curl

mkdir -p /etc/tor/t_sin_nodes
mkdir -p /var/lib/tor/t_sin_nodes

echo
echo "Installation completed."
echo
echo "Run the main script:"
echo
echo "bash tor-automate.sh"