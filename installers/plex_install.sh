#!/bin/bash

# Plex Media Server Installation Script
# Based on WAWYC (What Are We Worried You Can't) instructions

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${MAGENTA}🎬 Installing Plex Media Server...${NC}"

# Check if Plex is already installed and running
if systemctl is-active --quiet plexmediaserver 2>/dev/null; then
    echo -e "${GREEN}✅ Plex Media Server is already installed and running${NC}"
    
    # Get internal IP for display
    SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+' || hostname -I | awk '{print $1}')
    
    echo -e "${CYAN}📺 Current Plex Information:${NC}"
    echo -e "${BLUE}   • Web Interface: ${WHITE}http://$SERVER_IP:32400/web${NC}"
    echo -e "${BLUE}   • Service Status: ${WHITE}Running${NC}"
    echo -e "${CYAN}📝 Plex installation skipped - already configured${NC}"
    exit 0
fi

# WAWYC Plex Installation Implementation
echo -e "${YELLOW}  → Installing dependencies${NC}"
apt-get update
apt-get install -y curl wget

echo -e "${YELLOW}  → Adding Plex repository${NC}"
# Add Plex signing key
curl -s https://downloads.plex.tv/plex-keys/PlexSign.key | apt-key add -

# Add Plex repository
echo "deb https://downloads.plex.tv/repo/deb public main" > /etc/apt/sources.list.d/plexmediaserver.list

echo -e "${YELLOW}  → Updating package lists${NC}"
apt-get update

echo -e "${YELLOW}  → Installing Plex Media Server${NC}"
apt-get install -y plexmediaserver

echo -e "${YELLOW}  → Configuring Plex service${NC}"
systemctl enable plexmediaserver

echo -e "${YELLOW}  → Setting up user permissions${NC}"
# Get the original user (the one who ran sudo)
ORIG_USER="${SUDO_USER:-$USER}"
if [[ -n "$ORIG_USER" && "$ORIG_USER" != "root" ]]; then
    # Add user to plex group for media access
    usermod -a -G plex "$ORIG_USER"
    echo -e "${GREEN}    ✓ User '$ORIG_USER' added to plex group${NC}"
    
    # Add user to media group (if it exists)
    if getent group media >/dev/null 2>&1; then
        usermod -a -G media plex
        echo -e "${GREEN}    ✓ Plex user added to media group${NC}"
    fi
else
    echo -e "${YELLOW}    Warning: Could not determine user for group assignment${NC}"
fi

echo -e "${YELLOW}  → Starting Plex Media Server${NC}"
systemctl start plexmediaserver

echo -e "${YELLOW}  → Waiting for Plex to initialize${NC}"
sleep 5

echo -e "${YELLOW}  → Verifying Plex service status${NC}"
if systemctl is-active --quiet plexmediaserver; then
    echo -e "${GREEN}    ✓ Plex Media Server is running${NC}"
else
    echo -e "${RED}    ✗ Plex Media Server failed to start${NC}"
    systemctl status plexmediaserver --no-pager
    exit 1
fi

# Set up media directory permissions for Plex
echo -e "${YELLOW}  → Configuring media directory access${NC}"
if [[ -d "/srv/serverFilesystem" ]]; then
    # Give plex user access to media directories
    chown -R plex:plex /var/lib/plexmediaserver
    # Ensure plex can read media files
    chmod -R 755 /srv/serverFilesystem/media 2>/dev/null || true
    echo -e "${GREEN}    ✓ Media directory permissions configured${NC}"
fi

# Get internal IP for display (avoid VPN IP)
SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+' || hostname -I | awk '{print $1}')

echo -e "${GREEN}✅ Plex Media Server installed and configured successfully${NC}"
echo -e "${CYAN}📺 Plex Setup Information:${NC}"
echo -e "${BLUE}   • Web Interface: ${WHITE}http://$SERVER_IP:32400/web${NC}"
echo -e "${BLUE}   • Service Status: ${WHITE}Running and enabled${NC}"
echo -e "${BLUE}   • Media Directories: ${WHITE}/srv/serverFilesystem/media/${NC}"
echo -e "${BLUE}   • User Access: ${WHITE}$ORIG_USER added to plex group${NC}"
echo ""
echo -e "${CYAN}📋 Next Steps:${NC}"
echo -e "${WHITE}   1. Open web interface: ${YELLOW}http://$SERVER_IP:32400/web${NC}"
echo -e "${WHITE}   2. Complete initial setup and create Plex account${NC}"
echo -e "${WHITE}   3. Add media libraries pointing to:${NC}"
echo -e "${WHITE}      • Movies: ${CYAN}/srv/serverFilesystem/media/movies${NC}"
echo -e "${WHITE}      • TV Shows: ${CYAN}/srv/serverFilesystem/media/tv${NC}"
echo -e "${WHITE}      • Music: ${CYAN}/srv/serverFilesystem/media/music${NC}"
echo ""
echo -e "${CYAN}💡 Tips:${NC}"
echo -e "${WHITE}   • Plex will automatically scan and organize your media${NC}"
echo -e "${WHITE}   • Use Samba share to add media files to the directories${NC}"
echo -e "${WHITE}   • Check logs with: ${YELLOW}sudo journalctl -u plexmediaserver -f${NC}"