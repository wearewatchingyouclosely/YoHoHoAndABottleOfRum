#!/bin/bash
# qBittorrent Installation Script
# Based on WAWYC instructions with qbtuser creation and systemd service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/../wawycsuppliedconfigfiles/qbittorrent.service"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if qBittorrent is already installed and configured
if systemctl is-active --quiet qbittorrent 2>/dev/null; then
    echo -e "${GREEN}✅ qBittorrent is already installed and running${NC}"
    echo -e "${BLUE}ℹ️  Access via http://$(hostname -I | awk '{print $1}'):8080${NC}"
    echo -e "${YELLOW}⚠️  Skipping installation (service already active)${NC}"
    exit 0
fi

echo -e "${CYAN}🌊 Installing qBittorrent (WAWYC Method)...${NC}"

# Install qBittorrent-nox package
echo -e "${YELLOW}  → Installing qbittorrent-nox package${NC}"
apt-get install qbittorrent-nox -y

# Create qbtuser with interactive setup (WAWYC method)
echo -e "${YELLOW}  → Creating qbtuser${NC}"
if ! id "qbtuser" &>/dev/null; then
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                        👤 USER CREATION REQUIRED 👤                       ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                                            ║${NC}"
    echo -e "${CYAN}${BOLD}║  The system will now create the 'qbtuser' account with no prompts         ║${NC}"
    echo -e "${CYAN}${BOLD}║  except for password.                                                     ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                                            ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📝 Creating qbtuser account (only password prompt)${NC}"
    echo -e "${WHITE}   When prompted, set a password you'll remember${NC}"
    echo ""
    adduser --gecos "" qbtuser
else
    echo -e "${GREEN}✓ qbtuser already exists${NC}"
fi

# Add qbtuser to required groups
echo -e "${YELLOW}  → Adding qbtuser to sudo and media groups${NC}"
usermod -a -G sudo qbtuser
usermod -a -G media qbtuser

# Interactive qBittorrent setup as qbtuser
echo -e "${YELLOW}  → Running initial qBittorrent setup as qbtuser${NC}"
echo ""
echo -e "${RED}${BOLD}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}${BOLD}║                           🚨 ATTENTION REQUIRED 🚨                         ║${NC}"
echo -e "${RED}${BOLD}║                                                                            ║${NC}"
echo -e "${RED}${BOLD}║  CRITICAL USER INTERACTION NEEDED FOR QBITTORRENT SETUP                   ║${NC}"
echo -e "${RED}${BOLD}║                                                                            ║${NC}"
echo -e "${RED}${BOLD}║  The script will now switch to the 'qbtuser' environment to generate      ║${NC}"
echo -e "${RED}${BOLD}║  qBittorrent's initial configuration and temporary password.               ║${NC}"
echo -e "${RED}${BOLD}║                                                                            ║${NC}"
echo -e "${RED}${BOLD}║  IMPORTANT: You MUST capture the temporary password from the output!       ║${NC}"
echo -e "${RED}${BOLD}║                                                                            ║${NC}"
echo -e "${RED}${BOLD}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📋 CRITICAL SETUP PHASE - Please follow these steps carefully:${NC}"
echo ""
echo -e "${WHITE}This process will:${NC}"
echo -e "${WHITE}1. Start qBittorrent as qbtuser to generate initial config${NC}"
echo -e "${WHITE}2. Capture the TEMPORARY PASSWORD from the output${NC}"
echo -e "${WHITE}3. You'll use this temp password to set your permanent login${NC}"
echo ""
echo -e "${RED}⚠️  CRITICAL: The temporary password is REQUIRED to set your login!${NC}"
echo -e "${RED}⚠️  Default admin/adminadmin does NOT work reliably!${NC}"
echo ""
echo -e "${YELLOW}${BOLD}Press ENTER to continue with qBittorrent setup...${NC}"
read -r

# Switch to qbtuser and run qBittorrent to get initial password
echo -e "${CYAN}🔄 Starting qBittorrent as qbtuser to get temporary password...${NC}"
echo ""

# Copy the setup script from configFiles
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QBT_SETUP_SCRIPT="$SCRIPT_DIR/../configFiles/qbt_setup.sh"

if [[ ! -f "$QBT_SETUP_SCRIPT" ]]; then
    echo -e "${RED}❌ qBittorrent setup script not found at $QBT_SETUP_SCRIPT${NC}"
    exit 1
fi

# Copy setup script to temp location and make executable
cp "$QBT_SETUP_SCRIPT" /tmp/qbt_setup.sh
chmod +x /tmp/qbt_setup.sh


# Robust IP detection function (copied from main installer)
get_internal_ip() {
    # Enhanced method to avoid VPN IPs and get true local network IP (from MOTD)
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
    # Method 3: Use ip route to find the default route interface and get its IP
    ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+')
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi
    # Method 4: Last resort - try to find any non-loopback IP
    ip=$(hostname -I | awk '{print $1}')
    echo "${ip:-127.0.0.1}"
}

# Run as qbtuser and pass the server IP
echo -e "${YELLOW}🔍 Generating qBittorrent config and temporary password...${NC}"
echo ""
SERVER_IP=$(get_internal_ip)
su - qbtuser -c "/tmp/qbt_setup.sh $SERVER_IP"

# Configuration completed
echo ""
echo -e "${GREEN}${BOLD}✅ CONFIGURATION COMPLETED SUCCESSFULLY!${NC}"
echo -e "${WHITE}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}   qBittorrent Setup Complete${NC}"
echo -e "${WHITE}${BOLD}═══════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓ User should have successfully set their permanent password${NC}"
echo -e "${YELLOW}📋 Remember to configure qBittorrent using TRaSH Guides${NC}"
echo ""

# Clean up temporary files
rm -f /tmp/qbt_setup.sh /tmp/qbt_output.log

echo ""
echo -e "${GREEN}✅ Initial qBittorrent configuration completed${NC}"
echo -e "${CYAN}📝 Next: Installing systemd service for permanent operation${NC}"

# Install systemd service
echo -e "${YELLOW}  → Installing systemd service${NC}"
if [[ -f "$SERVICE_FILE" ]]; then
    cp "$SERVICE_FILE" /etc/systemd/system/qbittorrent.service
    echo -e "${GREEN}✓ Service file installed from wawycsuppliedconfigfiles${NC}"
else
    # Fallback: create service file directly
    echo -e "${YELLOW}⚠️ Creating service file (wawycsuppliedconfigfiles not found)${NC}"
    cat > /etc/systemd/system/qbittorrent.service << 'EOF'
[Unit]
Description=qBittorrent-nox service
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
# if you have systemd < 240 (Ubuntu 18.10 and earlier, for example), you probably want to use Type=simple instead
Type=exec
# change user as needed
User=qbtuser
# The -d flag should not be used in this setup
ExecStart=/usr/bin/qbittorrent-nox
# uncomment this for versions of qBittorrent < 4.2.0 to set the maximum number of open files to unlimited
#LimitNOFILE=infinity
# uncomment this to use "Network interface" and/or "Optional IP address to bind to" options
# without this binding will fail and qBittorrent's traffic will go through the default route
# AmbientCapabilities=CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF
fi

# Enable and start qBittorrent service
echo -e "${YELLOW}  → Enabling and starting qBittorrent service${NC}"
systemctl daemon-reload
systemctl enable qbittorrent
systemctl start qbittorrent

# Wait a moment for service to start
sleep 3

# Check service status
if systemctl is-active --quiet qbittorrent; then
    echo -e "${GREEN}✅ qBittorrent service started successfully${NC}"
else
    echo -e "${RED}❌ qBittorrent service failed to start${NC}"
    systemctl status qbittorrent --no-pager
fi

# Get server IP for web interface (VPN-aware method)

# Robust IP detection function (copied from main installer)
get_internal_ip() {
    # Enhanced method to avoid VPN IPs and get true local network IP (from MOTD)
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
    # Method 3: Use ip route to find the default route interface and get its IP
    ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+')
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi
    # Method 4: Last resort - try to find any non-loopback IP
    ip=$(hostname -I | awk '{print $1}')
    echo "${ip:-127.0.0.1}"
}

SERVER_IP=$(get_internal_ip)

echo ""
echo -e "${GREEN}✅ qBittorrent installation completed!${NC}"
echo ""
echo -e "${CYAN}🌐 Web Interface Access:${NC}"
echo -e "${WHITE}   URL: ${BLUE}http://$SERVER_IP:8080${NC}"
if [[ -n "$TEMP_PASSWORD" ]]; then
    echo -e "${WHITE}   Username: ${YELLOW}admin${NC}"
    echo -e "${WHITE}   Password: ${RED}${BOLD}$TEMP_PASSWORD${NC} ${WHITE}(temporary - change this!)${NC}"
else
    echo -e "${WHITE}   Username: ${YELLOW}admin${NC}"
    echo -e "${WHITE}   Password: ${RED}${BOLD}Use the temporary password shown above${NC}"
fi
echo ""
echo -e "${RED}🔒 CRITICAL FIRST STEPS:${NC}"
echo -e "${WHITE}   1. Login with temporary password above${NC}"
echo -e "${WHITE}   2. Go to Tools → Options → Web UI${NC}"
echo -e "${WHITE}   3. Set a permanent admin password${NC}"
echo -e "${WHITE}   4. Consider enabling 'Bypass authentication for clients on localhost'${NC}"
echo ""
echo -e "${YELLOW}⚠️  NOTE: Default admin/adminadmin does NOT work reliably!${NC}"
echo -e "${YELLOW}⚠️  You MUST use the temporary password generated during setup!${NC}"
echo ""
echo -e "${BLUE}📖 Configuration Recommendations:${NC}"
echo -e "${WHITE}   • Downloads folder: ${CYAN}/srv/serverFilesystem/downloads${NC}"
echo -e "${WHITE}   • Completed folder: ${CYAN}/srv/serverFilesystem/downloads${NC}"
echo -e "${WHITE}   • Watch folder: ${CYAN}/srv/serverFilesystem/watch${NC}"
echo -e "${WHITE}   • See trash-guides.info for optimal settings${NC}"