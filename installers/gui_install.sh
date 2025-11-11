#!/bin/bash
# GUI Installation Script
# Installs Desktop GUI (Ubuntu GNOME or Debian GNOME)

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="$ID"
else
    OS_ID="unknown"
fi

echo -e "${CYAN}🖥️ Installing Desktop GUI for ${OS_ID}...${NC}"

case "$OS_ID" in
    ubuntu)
        echo -e "${YELLOW}  → Installing ubuntu-desktop-minimal${NC}"
        # TODO: apt-get install ubuntu-desktop-minimal -y
        echo -e "${BLUE}ℹ️  Ubuntu Desktop GUI is future functionality${NC}"
        ;;
    debian)
        echo -e "${YELLOW}  → Installing task-gnome-desktop${NC}"
        # TODO: apt-get install task-gnome-desktop -y
        echo -e "${BLUE}ℹ️  Debian GNOME Desktop is future functionality${NC}"
        ;;
    *)
        echo -e "${YELLOW}  → Installing generic desktop environment${NC}"
        # TODO: apt-get install xorg gnome-core -y
        echo -e "${BLUE}ℹ️  Generic Desktop GUI is future functionality${NC}"
        ;;
esac

echo -e "${YELLOW}  → Configuring display manager${NC}"
# TODO: systemctl set-default graphical.target

echo -e "${YELLOW}  → Setting up auto-login (optional)${NC}"
# TODO: Configure auto-login if desired

echo -e "${GREEN}Desktop GUI installation prepared for $OS_ID${NC}"
echo -e "${BLUE}ℹ️  tip your programmers im here all week${NC}"