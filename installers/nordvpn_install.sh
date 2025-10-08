#!/bin/bash
# NordVPN Installation Script
# Based on WAWYC instructions with snap installation and allowlisting

set -e

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

echo -e "${CYAN}🛡️ Installing NordVPN (WAWYC Method)...${NC}"

# WAWYC NordVPN Installation Implementation
echo -e "${YELLOW}  → Creating nordvpn group (GID 13001)${NC}"
groupadd -g 13001 nordvpn 2>/dev/null || echo "Group 'nordvpn' already exists"

echo -e "${YELLOW}  → Adding user to nordvpn group${NC}"
ORIG_USER="${SUDO_USER:-$USER}"
if [[ -n "$ORIG_USER" && "$ORIG_USER" != "root" ]]; then
    usermod -aG nordvpn "$ORIG_USER"
    echo -e "${GREEN}    ✓ User '$ORIG_USER' added to nordvpn group${NC}"
else
    echo -e "${YELLOW}    Warning: Could not determine user to add to nordvpn group${NC}"
fi

echo -e "${YELLOW}  → Installing NordVPN via snap${NC}"
snap install nordvpn

echo -e "${YELLOW}  → Connecting snap interfaces${NC}"
snap connect nordvpn:system-observe
snap connect nordvpn:hardware-observe
snap connect nordvpn:network-control
snap connect nordvpn:network-observe
snap connect nordvpn:firewall-control
snap connect nordvpn:login-session-observe

echo -e "${YELLOW}  → Waiting for NordVPN daemon to initialize${NC}"
sleep 3

echo -e "${YELLOW}  → Disabling NordVPN firewall${NC}"
nordvpn set firewall off

echo -e "${YELLOW}  → Detecting and allowlisting local network${NC}"
# Enhanced local network detection avoiding VPN interfaces
LOCAL_NET=""
for interface in eth0 ens160 ens192 ens33 enp0s3 enp0s8 wlan0 wlp2s0; do
    LOCAL_NET=$(ip route show dev "$interface" 2>/dev/null | grep -E "192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\." | grep "/" | head -1 | awk '{print $1}')
    if [[ -n "$LOCAL_NET" ]]; then
        break
    fi
done

# Fallback to any private network if specific interface not found
if [[ -z "$LOCAL_NET" ]]; then
    LOCAL_NET=$(ip route show | grep -E "192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\." | grep -v default | grep "/" | grep -v nordlynx | grep -v tun | head -1 | awk '{print $1}')
fi

if [[ -n "$LOCAL_NET" ]]; then
    echo -e "${BLUE}    Local network detected: $LOCAL_NET${NC}"
    nordvpn allowlist add subnet "$LOCAL_NET"
    echo -e "${GREEN}    ✓ Local network '$LOCAL_NET' added to allowlist${NC}"
else
    echo -e "${YELLOW}    Warning: Could not auto-detect local network${NC}"
    echo -e "${CYAN}    You may need to manually allowlist your local network later${NC}"
fi

echo -e "${YELLOW}  → Allowlisting essential ports (1-9999)${NC}"
# Use both commands for compatibility with different NordVPN versions
nordvpn allowlist add ports 1 9999 2>/dev/null || nordvpn whitelist add ports 1 9999
echo -e "${GREEN}    ✓ Ports 1-9999 added to allowlist${NC}"

echo -e "${YELLOW}  → Verifying NordVPN installation${NC}"
if nordvpn --version >/dev/null 2>&1; then
    NORDVPN_VERSION=$(nordvpn --version | head -1)
    echo -e "${GREEN}    ✓ NordVPN installed successfully: $NORDVPN_VERSION${NC}"
else
    echo -e "${RED}    ✗ NordVPN installation verification failed${NC}"
    exit 1
fi

# Auto-login if token was provided
if [[ -n "$NORDVPN_TOKEN" ]]; then
    echo -e "${YELLOW}  → Logging in with provided token${NC}"
    if nordvpn login --token "$NORDVPN_TOKEN"; then
        echo -e "${GREEN}    ✓ Successfully logged in to NordVPN${NC}"
        
        echo -e "${YELLOW}  → Enabling auto-connect${NC}"
        nordvpn set autoconnect on
        
        echo -e "${YELLOW}  → Connecting to NordVPN${NC}"
        if nordvpn connect; then
            echo -e "${GREEN}    ✓ Connected to NordVPN${NC}"
            sleep 2
            nordvpn status
        else
            echo -e "${YELLOW}    Warning: Could not connect automatically${NC}"
        fi
    else
        echo -e "${RED}    ✗ Login failed - please check your token${NC}"
        echo -e "${CYAN}    You can login manually later with: nordvpn login --token YOUR_TOKEN${NC}"
    fi
else
    echo -e "${BLUE}    ℹ️ No token provided - manual login required${NC}"
fi

echo -e "${GREEN}✅ NordVPN installed and configured successfully${NC}"
echo -e "${CYAN}🔐 Setup Information:${NC}"
echo -e "${BLUE}   • Group: ${WHITE}nordvpn (GID 13001)${NC}"
echo -e "${BLUE}   • User Access: ${WHITE}$ORIG_USER added to nordvpn group${NC}"
echo -e "${BLUE}   • Firewall: ${WHITE}Disabled${NC}"
echo -e "${BLUE}   • Local Network: ${WHITE}${LOCAL_NET:-Not auto-detected}${NC}"
echo -e "${BLUE}   • Port Allowlist: ${WHITE}1-9999${NC}"
echo ""
if [[ -z "$NORDVPN_TOKEN" ]]; then
    echo -e "${CYAN}📋 Next Steps (Manual Setup Required):${NC}"
    echo -e "${WHITE}   1. Get your token from: https://my.nordaccount.com/dashboard/nordvpn/manual-setup/${NC}"
    echo -e "${WHITE}   2. Login: ${YELLOW}nordvpn login --token YOUR_TOKEN${NC}"
    echo -e "${WHITE}   3. Enable auto-connect: ${YELLOW}nordvpn set autoconnect on${NC}"
    echo -e "${WHITE}   4. Connect: ${YELLOW}nordvpn connect${NC}"
    echo -e "${WHITE}   5. Check status: ${YELLOW}nordvpn status${NC}"
else
    echo -e "${CYAN}📋 NordVPN Ready to Use:${NC}"
    echo -e "${WHITE}   • Already logged in and connected${NC}"
    echo -e "${WHITE}   • Auto-connect enabled for future reboots${NC}"
    echo -e "${WHITE}   • Check status anytime: ${YELLOW}nordvpn status${NC}"
fi
echo ""
echo -e "${CYAN}💡 Useful Commands:${NC}"
echo -e "${WHITE}   • Check status: ${YELLOW}nordvpn status${NC}"
echo -e "${WHITE}   • List countries: ${YELLOW}nordvpn countries${NC}"
echo -e "${WHITE}   • Connect to specific country: ${YELLOW}nordvpn connect COUNTRY${NC}"
echo -e "${WHITE}   • Disconnect: ${YELLOW}nordvpn disconnect${NC}"