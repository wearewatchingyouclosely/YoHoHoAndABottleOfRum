#!/bin/bash
# Dashboard Quick Fix Script
# Cleans up and reinstalls dashboard properly

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}🛠️  Dashboard Quick Fix${NC}"
echo -e "${YELLOW}Cleaning up broken installation...${NC}"

# Stop and disable service
sudo systemctl stop media-dashboard 2>/dev/null
sudo systemctl disable media-dashboard 2>/dev/null

# Remove broken installation
sudo rm -rf /opt/dashboard
sudo rm -f /etc/systemd/system/media-dashboard.service

# Remove dashboard user 
sudo userdel dashboard 2>/dev/null

echo -e "${GREEN}✅ Cleanup completed${NC}"
echo -e "${YELLOW}Installing required packages...${NC}"

# Install missing packages
sudo apt update
sudo apt install -y python3-pip python3-venv python3-flask python3-requests

echo -e "${GREEN}✅ Dependencies installed${NC}"
echo -e "${YELLOW}Now run the dashboard installer:${NC}"
echo -e "${CYAN}sudo bash installers/dashboard_install.sh${NC}"