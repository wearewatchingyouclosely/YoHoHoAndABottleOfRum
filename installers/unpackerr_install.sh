#!/bin/bash
# Unpackerr Installation Script
# Based on WAWYC instructions with configuration from wawycsuppliedconfigfiles

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../configFiles/unpackerr.conf"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

SERVICE_NAME="unpackerr"

# Check if Unpackerr is already installed and running
if systemctl is-active --quiet unpackerr 2>/dev/null; then
    echo -e "${GREEN}✅ Unpackerr is already installed and running${NC}"
    echo -e "${BLUE}ℹ️  Background service - automatically extracts downloaded archives${NC}"
    echo -e "${YELLOW}⚠️  Skipping installation (service already active)${NC}"
    exit 0
fi

echo -e "${CYAN}📦 Installing Unpackerr (WAWYC Method)...${NC}"
echo -e "${BLUE}📝 Unpackerr automatically extracts archives from downloads${NC}"

# Install Unpackerr using official GoLift repository (WAWYC method)
echo -e "${YELLOW}  → Installing Unpackerr via GoLift repository${NC}"
if ! curl -s https://golift.io/repo.sh | sudo bash -s - unpackerr; then
    echo -e "${RED}❌ Failed to install Unpackerr via GoLift repository${NC}"
    exit 1
fi

# Apply configuration from configFiles
echo -e "${YELLOW}  → Applying WAWYC configuration${NC}"
if [[ -f "$CONFIG_FILE" ]]; then
    sudo cp "$CONFIG_FILE" /etc/unpackerr/unpackerr.conf
    sudo chown root:root /etc/unpackerr/unpackerr.conf
    sudo chmod 644 /etc/unpackerr/unpackerr.conf
else
    echo -e "${YELLOW}⚠️  Configuration file not found, using default config${NC}"
fi

# Add unpackerr user to media group for proper permissions
echo -e "${YELLOW}  → Configuring user permissions${NC}"
if getent group media >/dev/null 2>&1; then
    sudo usermod -aG media unpackerr
else
    echo -e "${YELLOW}⚠️  Media group not found, creating it${NC}"
    sudo groupadd -g 13000 media
    sudo usermod -aG media unpackerr
fi

# Enable and start Unpackerr service
echo -e "${YELLOW}  → Enabling and starting Unpackerr service${NC}"
sudo systemctl enable unpackerr
sudo systemctl start unpackerr

# Wait for service to initialize and check status
echo -e "${YELLOW}  → Checking service status...${NC}"
sleep 3

if systemctl is-active --quiet unpackerr; then
    echo ""
    echo -e "${GREEN}✅ Unpackerr installation completed successfully!${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN} 📦 Unpackerr Archive Extractor${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}🤖 Function: Automatically extracts downloaded archives${NC}"
    echo -e "${CYAN}📂 Monitors: /srv/serverFilesystem/downloads/complete${NC}"
    echo -e "${CYAN}🔄 Process: RAR/ZIP files → extracted → deleted${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📝 How it works:${NC}"
    echo -e "${WHITE}  • Monitors download completion from *arr services${NC}"
    echo -e "${WHITE}  • Extracts RAR, ZIP, 7Z archives automatically${NC}"
    echo -e "${WHITE}  • Deletes archive files after successful extraction${NC}"
    echo -e "${WHITE}  • Integrates with Radarr, Sonarr, and qBittorrent${NC}"
    echo ""
    echo -e "${YELLOW}📋 No manual configuration needed - runs in background${NC}"
else
    echo -e "${RED}❌ Unpackerr service failed to start properly${NC}"
    echo -e "${YELLOW}  Checking service status...${NC}"
    sudo systemctl status unpackerr --no-pager -l
    exit 1
fi