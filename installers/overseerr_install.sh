#!/bin/bash
# Overseerr Request Manager Installation Script
# Based on WAWYC instructions using Snap package

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

SERVICE_NAME="overseerr"

# Get internal IP address (excluding VPN interfaces)
get_internal_ip() {
    # Enhanced method to avoid VPN IPs and get true local network IP
    local ip=""
    
    # Method 1: Find physical interface IP (avoid VPN tunnels)
    for interface in eth0 ens160 ens192 ens33 enp0s3 enp0s8 wlan0 wlp2s0; do
        ip=$(ip addr show "$interface" 2>/dev/null | grep -oP 'inet \K192\.168\.[0-9]+\.[0-9]+|inet \K10\.[0-9]+\.[0-9]+\.[0-9]+|inet \K172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+' | head -1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    # Method 2: Get private range IPs, but exclude common VPN ranges
    for iface_ip in $(ip addr show | grep -E 'inet (192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | grep -v 'inet 127\.' | awk '{print $2}' | cut -d'/' -f1); do
        local iface=$(ip addr show | grep "$iface_ip" | grep -oP '^\d+: \K[^:]+' | head -1)
        if [[ ! "$iface" =~ ^(nordlynx|tun|tap|ppp|wg) ]]; then
            echo "$iface_ip"
            return 0
        fi
    done
    
    # Fallback
    ip=$(hostname -I | tr ' ' '\n' | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | head -1)
    echo "${ip:-127.0.0.1}"
}

# Check if Overseerr is already installed and running

# Check if Overseerr is already installed and running (systemd)
if systemctl is-active --quiet snap.overseerr.overseerr 2>/dev/null; then
    SERVER_IP=$(get_internal_ip)
    echo -e "${GREEN}✅ Overseerr is already installed and running${NC}"
    echo -e "${BLUE}ℹ️  Access via http://$SERVER_IP:5055${NC}"
    echo -e "${YELLOW}⚠️  Skipping installation (already installed)${NC}"
    exit 0
fi

# Check if snap overseerr is already installed
if snap list overseerr 2>/dev/null | grep -q '^overseerr '; then
    SERVER_IP=$(get_internal_ip)
    echo -e "${GREEN}✅ Overseerr snap package is already installed${NC}"
    echo -e "${BLUE}ℹ️  Access via http://$SERVER_IP:5055${NC}"
    echo -e "${YELLOW}⚠️  Skipping installation (snap already installed)${NC}"
    exit 0
fi

echo -e "${CYAN}📋 Installing Overseerr Request Manager (WAWYC Method)...${NC}"

# Install snapd if not present
if ! command -v snap >/dev/null 2>&1; then
    echo -e "${YELLOW}  → Installing snapd${NC}"
    sudo apt update
    sudo apt install -y snapd
fi

# Install Overseerr via Snap (WAWYC method)
echo -e "${YELLOW}  → Installing Overseerr from Snap Store${NC}"
if ! sudo snap install overseerr; then
    echo -e "${RED}❌ Failed to install Overseerr via Snap${NC}"
    exit 1
fi

# Wait a moment for the service to initialize
echo -e "${YELLOW}  → Waiting for Overseerr service to initialize...${NC}"
sleep 5

# Enable and start the Overseerr service
echo -e "${YELLOW}  → Enabling Overseerr service${NC}"
sudo systemctl enable snap.overseerr.overseerr

# Start the service if not already running
if ! systemctl is-active --quiet snap.overseerr.overseerr; then
    echo -e "${YELLOW}  → Starting Overseerr service${NC}"
    sudo systemctl start snap.overseerr.overseerr
fi

# Wait for service to be ready and check status
echo -e "${YELLOW}  → Checking service status...${NC}"
sleep 3

if systemctl is-active --quiet snap.overseerr.overseerr; then
    SERVER_IP=$(get_internal_ip)
    
    echo ""
    echo -e "${GREEN}✅ Overseerr installation completed successfully!${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN} 🎭 Overseerr Request Manager${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}📍 Web Interface: http://$SERVER_IP:5055${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📝 Configuration Notes:${NC}"
    echo -e "${WHITE}  • Connect to your Plex server during initial setup${NC}"
    echo -e "${WHITE}  • Add Radarr and Sonarr for automatic downloads${NC}"
    echo -e "${WHITE}  • Configure user permissions and request limits${NC}"
    echo -e "${WHITE}  • Set up email notifications (optional)${NC}"
    echo ""
    echo -e "${YELLOW}📚 See TRaSH Guides for advanced configuration${NC}"
else
    echo -e "${RED}❌ Overseerr service failed to start properly${NC}"
    echo -e "${YELLOW}  Checking service status...${NC}"
    sudo systemctl status snap.overseerr.overseerr --no-pager -l
    exit 1
fi