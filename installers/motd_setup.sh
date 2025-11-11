#!/bin/bash

# Dynamic MOTD Generator
# Based on WAWYC instructions

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOTD_DIR="$SCRIPT_DIR/../MOTD"

# Get internal IP address (excluding VPN interfaces)
get_internal_ip() {
    # Enhanced method to avoid VPN IPs and get true local network IP
    local ip=""
    
    # Method 1: Find physical interface IP (avoid VPN tunnels)
    # Look for common physical interfaces and get their IP from private ranges
    for interface in eth0 ens160 ens192 ens33 enp0s3 enp0s8 wlan0 wlp2s0; do
        ip=$(ip addr show "$interface" 2>/dev/null | grep -oP 'inet \K192\.168\.[0-9]+\.[0-9]+|inet \K10\.[0-9]+\.[0-9]+\.[0-9]+|inet \K172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+' | head -1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    # Method 2: Get private range IPs, but exclude common VPN ranges
    # Exclude nordlynx, tun, tap, ppp interfaces
    for iface_ip in $(ip addr show | grep -E 'inet (192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | grep -v 'inet 127\.' | awk '{print $2}' | cut -d'/' -f1); do
        # Get interface name for this IP
        local iface=$(ip addr show | grep "$iface_ip" | grep -oP '^\d+: \K[^:]+' | head -1)
        # Skip known VPN interface patterns
        if [[ ! "$iface" =~ ^(nordlynx|tun|tap|ppp|wg) ]]; then
            echo "$iface_ip"
            return 0
        fi
    done
    
    # Method 3: Use hostname -I but filter out VPN ranges
    ip=$(hostname -I | tr ' ' '\n' | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | head -1)
    
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi
    
    # Method 4: Last resort - try to find any non-loopback IP
    ip=$(hostname -I | awk '{print $1}')
    echo "${ip:-127.0.0.1}"
}

# Service status checking function
check_service_status() {
    local service_url="$1"
    local timeout=3
    
    if curl -s --max-time $timeout "$service_url" >/dev/null 2>&1; then
        echo -e "${GREEN}●${NC}"
    else
        echo -e "${RED}●${NC}"
    fi
}

# Generate dynamic MOTD
generate_motd() {
    local server_ip=$(get_internal_ip)
    
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}                        SERVICE STATUS${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check and display service statuses
    # Samba (file share - no web UI, check if service is running)
    if systemctl is-active --quiet smbd 2>/dev/null; then
        samba_status="${GREEN}●${NC}"
    else
        samba_status="${RED}●${NC}"
    fi
    echo -e "  $samba_status ${WHITE}Samba File Share:${NC}    \\\\\\\\$server_ip\\\\sambashare"
    
    # Prowlarr
    prowlarr_status=$(check_service_status "http://$server_ip:9696")
    echo -e "  $prowlarr_status ${WHITE}Prowlarr (Indexers):${NC} http://$server_ip:9696"
    
    # Radarr
    radarr_status=$(check_service_status "http://$server_ip:7878")
    echo -e "  $radarr_status ${WHITE}Radarr (Movies):${NC}     http://$server_ip:7878"
    
    # Sonarr  
    sonarr_status=$(check_service_status "http://$server_ip:8989")
    echo -e "  $sonarr_status ${WHITE}Sonarr (TV):${NC}         http://$server_ip:8989"
    
    # Plex
    plex_status=$(check_service_status "http://$server_ip:32400/web")
    echo -e "  $plex_status ${WHITE}Plex Media Server:${NC}   http://$server_ip:32400/web"
    
    # Overseerr
    overseerr_status=$(check_service_status "http://$server_ip:5055")
    echo -e "  $overseerr_status ${WHITE}Overseerr (Requests):${NC} http://$server_ip:5055"
    
    # qBittorrent
    qbit_status=$(check_service_status "http://$server_ip:8080")
    echo -e "  $qbit_status ${WHITE}qBittorrent:${NC}         http://$server_ip:8080"
    
    # Prometheus
    prometheus_status=$(check_service_status "http://$server_ip:9090")
    echo -e "  $prometheus_status ${WHITE}Prometheus (Monitoring):${NC} http://$server_ip:9090"
    
    # Dashboard
    dashboard_status=$(check_service_status "http://$server_ip:3000")
    echo -e "  $dashboard_status ${WHITE}Web Dashboard (Mobile):${NC}  http://$server_ip:3000"
    
    # NordVPN status (dynamic check)
    echo ""
    echo -e "${YELLOW}${BOLD}VPN & Other Services:${NC}"
    
    # Check NordVPN status
    if command -v nordvpn >/dev/null 2>&1; then
        nordvpn_status=$(nordvpn status 2>/dev/null)
        if echo "$nordvpn_status" | grep -q "Status: Connected"; then
            # Extract key information
            local vpn_server=$(echo "$nordvpn_status" | grep "Server:" | awk '{print $2, $3}')
            local vpn_country=$(echo "$nordvpn_status" | grep "Country:" | awk '{print $2}')
            local vpn_city=$(echo "$nordvpn_status" | grep "City:" | awk '{print $2}')
            local vpn_tech=$(echo "$nordvpn_status" | grep "Current technology:" | awk '{print $3}')
            
            echo -e "  ${GREEN}●${NC} ${WHITE}NordVPN:${NC}             ${GREEN}Connected${NC} - ${CYAN}$vpn_country/$vpn_city${NC} (${YELLOW}$vpn_tech${NC})"
            if [[ -n "$vpn_server" ]]; then
                echo -e "    ${WHITE}Server:${NC} $vpn_server"
            fi
        elif echo "$nordvpn_status" | grep -q "Status: Disconnected"; then
            echo -e "  ${YELLOW}●${NC} ${WHITE}NordVPN:${NC}             ${YELLOW}Disconnected${NC} - ${CYAN}use 'nordvpn connect'${NC}"
        else
            echo -e "  ${RED}●${NC} ${WHITE}NordVPN:${NC}             ${RED}Not logged in${NC} - ${CYAN}use 'nordvpn login --token TOKEN'${NC}"
        fi
    else
        echo -e "  ${RED}●${NC} ${WHITE}NordVPN:${NC}             ${RED}Not installed${NC}"
    fi
    
    # Unpackerr (background archive extraction service)
    if systemctl is-active --quiet unpackerr 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} ${WHITE}Unpackerr:${NC}           ${GREEN}Running${NC} - ${CYAN}Auto-extracts archives${NC}"
        echo -e "    ${WHITE}Function:${NC} Automatically unarchives downloaded RAR/ZIP files"
    elif systemctl is-enabled --quiet unpackerr 2>/dev/null; then
        echo -e "  ${YELLOW}●${NC} ${WHITE}Unpackerr:${NC}           ${YELLOW}Stopped${NC} - ${CYAN}use 'sudo systemctl start unpackerr'${NC}"
    else
        echo -e "  ${RED}●${NC} ${WHITE}Unpackerr:${NC}           ${RED}Not installed${NC} - ${CYAN}Archive extraction service${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}${BOLD}Configuration Resources:${NC}"
    echo -e "  📚 ${WHITE}TRaSH Guides:${NC}         ${CYAN}https://trash-guides.info/${NC}"
    echo -e "     ${WHITE}Essential for configuring Sonarr, Radarr, and qBittorrent${NC}"
    
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    

        # Display banner
    if [[ -f "$MOTD_DIR/motd-banner.txt" ]]; then
        echo -e "${PURPLE}${BOLD}"
        cat "$MOTD_DIR/motd-banner.txt"
        echo -e "${NC}"
    fi

    # Random quote at bottom
    if [[ -f "$MOTD_DIR/motd-quotes.txt" ]]; then
        local quote=$(shuf -n 1 "$MOTD_DIR/motd-quotes.txt")
        echo -e "${WHITE}${BOLD}  Message Of The Minute:${NC} ${CYAN}\"$quote\"${NC}"
    fi
    
    echo ""
}

# Main function
main() {
    generate_motd
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi