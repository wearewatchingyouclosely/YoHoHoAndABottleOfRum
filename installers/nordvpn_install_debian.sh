#!/bin/bash
# Debian-compatible NordVPN installer
# Alternative to snap-based installation

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}📶 Installing NordVPN (Debian method)...${NC}"

# Check Debian version
DEBIAN_VERSION=$(lsb_release -rs 2>/dev/null || cat /etc/debian_version)
echo -e "${YELLOW}Detected Debian version: $DEBIAN_VERSION${NC}"

# Method 1: Official DEB package (recommended)
echo -e "${YELLOW}  → Downloading NordVPN DEB package${NC}"
cd /tmp
wget "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb"

if [[ -f "nordvpn-release_1.0.0_all.deb" ]]; then
    sudo dpkg -i nordvpn-release_1.0.0_all.deb
    sudo apt update
    sudo apt install -y nordvpn
else
    echo -e "${RED}❌ Failed to download NordVPN package${NC}"
    exit 1
fi

# Rest of setup (same as Ubuntu version)
echo -e "${GREEN}✅ NordVPN installed successfully${NC}"
echo -e "${YELLOW}📝 Configure with: nordvpn login --token YOUR_TOKEN${NC}"