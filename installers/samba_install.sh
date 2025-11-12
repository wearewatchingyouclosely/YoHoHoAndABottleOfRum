#!/bin/bash
# Samba Installation Script
# Based on WAWYC instructions with smb.conf from wawycsuppliedconfigfiles

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SOURCE="$SCRIPT_DIR/../configFiles/smb.conf"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'

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

echo -e "${CYAN}📁 Installing Samba File Server (WAWYC Method)...${NC}"

# Check if Samba is already installed and configured
if systemctl is-active --quiet smbd && [[ -f "/etc/samba/smb.conf" ]] && grep -q "sambashare" /etc/samba/smb.conf 2>/dev/null; then
    echo -e "${GREEN}✅ Samba is already installed and configured with WAWYC settings${NC}"
    
    # Get internal IP for display (VPN-aware)
    SERVER_IP=$(get_internal_ip)
    
    echo -e "${CYAN}📂 Current Share Information:${NC}"
    echo -e "${BLUE}   • Share Name: ${WHITE}sambashare${NC}"
    echo -e "${BLUE}   • Share Path: ${WHITE}/srv/serverFilesystem${NC}"
    echo -e "${BLUE}   • Windows Access: ${WHITE}\\\\\\\\${SERVER_IP}\\\\sambashare${NC}"
    echo -e "${CYAN}📝 Samba installation skipped - already configured${NC}"
    exit 0
fi

# WAWYC Samba Installation Implementation
echo -e "${YELLOW}  → Installing Samba package${NC}"
apt-get install -y samba

echo -e "${YELLOW}  → Enabling Samba service${NC}"
systemctl enable smbd

echo -e "${YELLOW}  → Stopping Samba service for configuration${NC}"
systemctl stop smbd 2>/dev/null || service smb stop 2>/dev/null || true

echo -e "${YELLOW}  → Backing up original smb.conf${NC}"
if [[ -f /etc/samba/smb.conf ]]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

echo -e "${YELLOW}  → Copying WAWYC smb.conf from configFiles${NC}"
if [[ -f "$CONFIG_SOURCE" ]]; then
    cp "$CONFIG_SOURCE" /etc/samba/smb.conf
    echo -e "${GREEN}    ✓ WAWYC smb.conf installed successfully${NC}"
else
    echo -e "${RED}    ✗ Error: smb.conf not found at $CONFIG_SOURCE${NC}"
    exit 1
fi

echo -e "${YELLOW}  → Setting proper permissions on smb.conf${NC}"
chmod 644 /etc/samba/smb.conf
chown root:root /etc/samba/smb.conf

echo -e "${YELLOW}  → Adding current user to Samba${NC}"
# Get the original user (the one who ran sudo)
ORIG_USER="${SUDO_USER:-$USER}"
if [[ -n "$ORIG_USER" && "$ORIG_USER" != "root" ]]; then
    # Check if user already exists in Samba
    if pdbedit -L | grep -q "^$ORIG_USER:"; then
        echo -e "${GREEN}    ✓ User '$ORIG_USER' already exists in Samba${NC}"
    else
        echo -e "${BLUE}    Adding user '$ORIG_USER' to Samba...${NC}"
        echo -e "${CYAN}    You will be prompted to set a Samba password for user '$ORIG_USER'${NC}"
        if smbpasswd -a "$ORIG_USER"; then
            echo -e "${GREEN}    ✓ User '$ORIG_USER' added to Samba successfully${NC}"
        else
            echo -e "${YELLOW}    Warning: Failed to add user '$ORIG_USER' to Samba${NC}"
            echo -e "${CYAN}    You can add the user later with: smbpasswd -a $ORIG_USER${NC}"
        fi
    fi
else
    echo -e "${YELLOW}    Warning: Could not determine user to add to Samba${NC}"
fi

echo -e "${YELLOW}  → Testing Samba configuration${NC}"
if testparm -s >/dev/null 2>&1; then
    echo -e "${GREEN}    ✓ Samba configuration is valid${NC}"
else
    echo -e "${RED}    ✗ Samba configuration has errors${NC}"
    echo -e "${CYAN}    Running testparm for details:${NC}"
    testparm
    exit 1
fi

echo -e "${YELLOW}  → Starting Samba services${NC}"
if systemctl restart smbd; then
    echo -e "${GREEN}    ✓ smbd service restarted${NC}"
else
    echo -e "${YELLOW}    Warning: smbd restart failed, trying alternative method${NC}"
    service smb restart 2>/dev/null || true
fi

# Restart nmbd (NetBIOS name service) - optional but recommended
if systemctl restart nmbd 2>/dev/null; then
    echo -e "${GREEN}    ✓ nmbd service restarted${NC}"
else
    echo -e "${YELLOW}    Note: nmbd service restart failed (may not be critical)${NC}"
fi

echo -e "${YELLOW}  → Verifying Samba service status${NC}"
if systemctl is-active --quiet smbd; then
    echo -e "${GREEN}    ✓ Samba service is running${NC}"
elif service smb status >/dev/null 2>&1; then
    echo -e "${GREEN}    ✓ Samba service is running (legacy check)${NC}"
else
    echo -e "${RED}    ✗ Samba service failed to start${NC}"
    echo -e "${CYAN}    Checking service status for troubleshooting:${NC}"
    systemctl status smbd --no-pager || service smb status
    exit 1
fi

# Get internal IP for display
SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+' || hostname -I | awk '{print $1}')

echo -e "${GREEN}✅ Samba File Server installed and configured successfully${NC}"
echo -e "${CYAN}📂 Share Information:${NC}"
echo -e "${BLUE}   • Share Name: ${WHITE}sambashare${NC}"
echo -e "${BLUE}   • Share Path: ${WHITE}/srv/serverFilesystem${NC}"
echo -e "${BLUE}   • Windows Access: ${WHITE}\\\\\\\\${SERVER_IP}\\\\sambashare${NC}"
echo -e "${BLUE}   • Guest Access: ${WHITE}Enabled${NC}"
echo -e "${BLUE}   • User Access: ${WHITE}Available for user '$ORIG_USER'${NC}"
echo ""
echo -e "${CYAN}💡 Usage Tips:${NC}"
echo -e "${WHITE}   • Windows: Open File Explorer, type \\\\\\\\${SERVER_IP}\\\\sambashare in address bar${NC}"
echo -e "${YELLOW}     ⚠️  Windows users: Enable SMB feature in Windows Features (search 'Turn Windows features on or off')${NC}"
echo -e "${WHITE}   • macOS: Finder → Go → Connect to Server → smb://${SERVER_IP}/sambashare${NC}"
echo -e "${WHITE}   • Linux: Files → Other Locations → smb://${SERVER_IP}/sambashare${NC}"