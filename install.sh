#!/usr/bin/env bash

# تعریف رنگ‌ها برای ظاهر حرفه‌ای‌تر
CYAN='\033[1;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

REPO="https://raw.githubusercontent.com/petrovveaceslav43-pixel/tor-automate/main"

# تابع برای چاپ پیام‌های مرتب
print_status() {
    echo -e "${CYAN}[*]${NC} $1"
}

clear
echo -e "${CYAN}========================================"
echo -e "      Tor Automate Engine Installer     "
echo -e "========================================${NC}"

print_status "Updating system packages..."
apt-get update -y > /dev/null 2>&1

print_status "Installing dependencies (tor, socat, curl)..."
apt-get install -y tor socat curl > /dev/null 2>&1

print_status "Downloading Tor Automate Engine..."
if curl -fsSL "$REPO/tor-automate.sh" -o /usr/local/bin/tor-automate; then
    chmod +x /usr/local/bin/tor-automate
    echo -e "${GREEN}[+] Installation Complete!${NC}"
else
    echo -e "${RED}[!] Download failed. Please check your internet connection.${NC}"
    exit 1
fi

echo -e "\n${CYAN}[*] Launching program...${NC}\n"
sleep 1

# اجرای برنامه
/usr/local/bin/tor-automate
