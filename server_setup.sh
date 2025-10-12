#!/bin/bash
# Ubuntu Media Server Setup Script
# Based on WAWYC tested instructions
# Version: 1.0 - Created: October 4, 2025

# Note: Removed 'set -e' to allow continuation after individual service failures

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/media-server-setup.log"
CONFIG_DIR="$SCRIPT_DIR/wawycsuppliedconfigfiles"
INSTALLERS_DIR="$SCRIPT_DIR/installers"

# Redirect output for logging while preserving user interaction
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

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

# Service tracking arrays
declare -A SERVICES
declare -A SERVICE_DESCRIPTIONS
declare -A INSTALL_FLAGS
declare -A INSTALL_RESULTS
declare -A INSTALL_ERRORS

# Initialize service mappings based on WAWYC instructions
SERVICES[1]="samba"
SERVICES[2]="nordvpn" 
SERVICES[3]="radarr"
SERVICES[4]="prowlarr"
SERVICES[5]="sonarr"
SERVICES[6]="plex"
SERVICES[7]="overseerr"
SERVICES[8]="qbittorrent"
SERVICES[9]="unpackerr"
SERVICES[10]="prometheus"
SERVICES[11]="dashboard"
SERVICES[G]="gui"

SERVICE_DESCRIPTIONS[1]="📁 Samba File Share"
SERVICE_DESCRIPTIONS[2]="🛡️  NordVPN"
SERVICE_DESCRIPTIONS[3]="🎬 Radarr (Movies)"
SERVICE_DESCRIPTIONS[4]="🔍 Prowlarr (Indexers)"
SERVICE_DESCRIPTIONS[5]="📺 Sonarr (TV Shows)"
SERVICE_DESCRIPTIONS[6]="� Plex Media Server"
SERVICE_DESCRIPTIONS[7]="📋 Overseerr (Requests)"
SERVICE_DESCRIPTIONS[8]="�🌊 qBittorrent (Torrents)"
SERVICE_DESCRIPTIONS[9]="📦 Unpackerr (Archives)"
SERVICE_DESCRIPTIONS[10]="📊 Prometheus (Monitoring)"
SERVICE_DESCRIPTIONS[11]="🎨 Web Dashboard (Mobile-Friendly)"
SERVICE_DESCRIPTIONS[G]="🖥️  Ubuntu Desktop GUI"

# Utility functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" >&3
}

print_header() {
    clear
    echo -e "${PURPLE}${BOLD}" >&3
    echo "╔══════════════════════════════════════════════════════════════════════════════╗" >&3
    echo "║                      🚀 MEDIA SERVER INSTALLER 🚀                           ║" >&3
    echo "║                    Based on A Bunch of Garbage and BS                       ║" >&3
    echo "║                         Professional Edition v1.0                           ║" >&3
    echo "╚══════════════════════════════════════════════════════════════════════════════╝" >&3
    echo -e "${NC}" >&3
    echo ""
    echo -e "${CYAN}${BOLD}i dont watch ads and i don't pay for anything!${NC}" >&3
    echo -e "${WHITE}all i really need is to be able to watch seinfeld${NC}" >&3
    echo ""
    echo -e "${YELLOW}${BOLD}📋 Terminal Copy/Paste Tips for Beginners:${NC}" >&3
    echo -e "${BLUE}  • Copy text: ${WHITE}Ctrl+Shift+C${NC} ${BLUE}(or right-click → Copy)${NC}" >&3
    echo -e "${BLUE}  • Paste text: ${WHITE}Ctrl+Shift+V${NC} ${BLUE}(or right-click → Paste)${NC}" >&3
    echo -e "${BLUE}  • Select text: ${WHITE}Click and drag${NC} ${BLUE}or ${WHITE}double-click${NC} ${BLUE}to select words${NC}" >&3
    echo -e "${BLUE}  • NordVPN token: ${WHITE}Copy from browser, paste here when prompted${NC}" >&3
    echo ""
}

print_fancy_box() {
    local title="$1"
    local color="$2"
    echo -e "${color}${BOLD}" >&3
    echo "╔══════════════════════════════════════════════════════════════════════════════╗" >&3
    echo "║$(printf "%-78s" " $title")║" >&3
    echo "╚══════════════════════════════════════════════════════════════════════════════╝" >&3
    echo -e "${NC}" >&3
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}❌ ROOT ACCESS REQUIRED${NC}" >&2
        echo -e "${WHITE}Please run this script with sudo (or try running sudo !! to repeat last command as sudo):${NC}" >&2
        echo -e "${YELLOW}  sudo $0${NC}" >&2
        exit 1
    fi
}

test_connectivity() {
    echo -e "${CYAN}🌐 Testing internet connectivity...${NC}" >&3
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Internet connection confirmed${NC}" >&3
        log "Internet connectivity test passed"
    else
        echo -e "${RED}❌ No internet connection detected${NC}" >&3
        echo -e "${WHITE}Please check your network and try again${NC}" >&3
        exit 1
    fi
}

show_service_menu() {
    print_fancy_box "🎯 SERVICE SELECTION MENU" "${CYAN}"
    echo ""
    echo -e "${WHITE}${BOLD}Available Services (All Recommended):${NC}" >&3
    echo ""
    
    # Core Services
    echo -e "${GREEN}${BOLD}🔧 CORE SERVICES${NC}" >&3
    echo -e "  ${WHITE}[1]${NC} ${SERVICE_DESCRIPTIONS[1]} ${GREEN}- Recommended${NC}" >&3
    echo -e "  ${WHITE}[2]${NC} ${SERVICE_DESCRIPTIONS[2]} ${GREEN}- Recommended${NC}" >&3
    echo ""
    
    # Media Management
    echo -e "${GREEN}${BOLD}🎭 MEDIA MANAGEMENT${NC}" >&3
    echo -e "  ${WHITE}[3]${NC} ${SERVICE_DESCRIPTIONS[3]} ${GREEN}- Recommended${NC}" >&3
    echo -e "  ${WHITE}[4]${NC} ${SERVICE_DESCRIPTIONS[4]} ${GREEN}- Recommended${NC}" >&3
    echo -e "  ${WHITE}[5]${NC} ${SERVICE_DESCRIPTIONS[5]} ${GREEN}- Recommended${NC}" >&3
    echo ""
    
    # Media Servers
    echo -e "${GREEN}${BOLD}🎭 MEDIA SERVERS${NC}" >&3
    echo -e "  ${WHITE}[6]${NC} ${SERVICE_DESCRIPTIONS[6]} ${GREEN}- Recommended${NC}" >&3
    echo -e "  ${WHITE}[7]${NC} ${SERVICE_DESCRIPTIONS[7]} ${GREEN}- Recommended${NC}" >&3
    echo ""
    
    # Download & Processing
    echo -e "${GREEN}${BOLD}⬬ DOWNLOAD & PROCESSING${NC}" >&3
    echo -e "  ${WHITE}[8]${NC} ${SERVICE_DESCRIPTIONS[8]} ${GREEN}- Recommended${NC}" >&3
    echo -e "  ${WHITE}[9]${NC} ${SERVICE_DESCRIPTIONS[9]} ${GREEN}- Recommended${NC}" >&3
    echo ""
    
    # Monitoring & Analytics
    echo -e "${GREEN}${BOLD}📊 MONITORING & ANALYTICS${NC}" >&3
    echo -e "  ${WHITE}[10]${NC} ${SERVICE_DESCRIPTIONS[10]} ${GREEN}- Recommended${NC}" >&3
    echo -e "  ${WHITE}[11]${NC} ${SERVICE_DESCRIPTIONS[11]} ${GREEN}- Recommended${NC}" >&3
    echo ""
    
    # Optional System Enhancement
    echo -e "${PURPLE}${BOLD}🖥️ SYSTEM ENHANCEMENT${NC}" >&3
    echo -e "  ${WHITE}[G]${NC} ${SERVICE_DESCRIPTIONS[G]} ${PURPLE}- FUTURE${NC}" >&3
    echo ""
    
    # Shortcuts
    echo -e "${CYAN}${BOLD}⚡ QUICK SHORTCUTS${NC}" >&3
    echo -e "  ${BOLD}${YELLOW}[A]${NC}   Install ALL recommended services (1-11)" >&3
    echo -e "  ${BOLD}${YELLOW}[AG]${NC}  Install ALL services + GUI (1-11 + G)" >&3
    echo ""
    
    echo -e "${BLUE}${BOLD}� SELECTION EXAMPLES${NC}" >&3
    echo -e "  ${WHITE}Single:${NC}     3                    ${GRAY}(Install Radarr only)${NC}" >&3
    echo -e "  ${WHITE}Multiple:${NC}   3 10 11              ${GRAY}(Radarr + Prometheus + Dashboard)${NC}" >&3
    echo -e "  ${WHITE}Comma:${NC}      1,2,6                ${GRAY}(Samba + NordVPN + Plex)${NC}" >&3
    echo -e "  ${WHITE}All:${NC}        A                    ${GRAY}(Everything recommended)${NC}" >&3
    echo ""
    
    echo -e "${WHITE}${BOLD}💫 Enter your selection${NC}: " >&3
}

parse_selection() {
    local input="$1"
    local -a selections=()
    
    # Handle shortcuts
    case "${input^^}" in
        "A")
            selections=(1 2 3 4 5 6 7 8 9 10 11)
            ;;
        "AG")
            selections=(1 2 3 4 5 6 7 8 9 10 11 G)
            ;;
        *)
            # Parse multiple selection formats: comma-separated OR space-separated
            if [[ "$input" == *","* ]]; then
                # Comma-separated: "1,2,3" or "1, 2, 3"
                IFS=',' read -ra selections <<< "${input// /}"
            else
                # Space-separated: "1 2 3" or single selection: "1"
                read -ra selections <<< "$input"
            fi
            ;;
    esac
    
    # Validate and set install flags
    local valid_count=0
    for selection in "${selections[@]}"; do
        if [[ -n "${SERVICES[$selection]}" ]]; then
            INSTALL_FLAGS["${SERVICES[$selection]}"]=true
            ((valid_count++))
        fi
    done
    
    if [[ $valid_count -eq 0 ]]; then
        echo -e "${RED}❌ No valid services selected${NC}" >&3
        return 1
    fi
    
    # Show confirmation
    echo ""
    print_fancy_box "✅ SELECTED SERVICES" "${GREEN}"
    echo ""
    for selection in "${selections[@]}"; do
        if [[ -n "${SERVICES[$selection]}" ]]; then
            echo -e "  ${GREEN}✓${NC} ${SERVICE_DESCRIPTIONS[$selection]}" >&3
        fi
    done
    
    echo ""
    echo -e "${CYAN}${BOLD}📊 Total services: ${YELLOW}$valid_count${NC}" >&3
    echo ""
    echo -e "${WHITE}${BOLD}🚀 Proceed with installation? ${GREEN}[Y/n]${NC}: " >&3
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Installation cancelled by user${NC}" >&3
        exit 0
    fi
    
    # Collect NordVPN token if NordVPN is selected
    if [[ "${INSTALL_FLAGS[nordvpn]}" == "true" ]]; then
        echo ""
        echo -e "${CYAN}${BOLD}🛡️ NordVPN Configuration${NC}" >&3
        echo -e "${WHITE}To complete NordVPN setup, we need your authentication token.${NC}" >&3
        echo -e "${BLUE}Get your token from: ${YELLOW}https://my.nordaccount.com/dashboard/nordvpn/manual-setup/${NC}" >&3
        echo ""
        echo -e "${WHITE}${BOLD}Enter your NordVPN token ${GREEN}(or press Enter to skip and configure later)${NC}: " >&3
        read -r NORDVPN_TOKEN
        
        if [[ -n "$NORDVPN_TOKEN" ]]; then
            export NORDVPN_TOKEN
            echo -e "${GREEN}✓ NordVPN token provided - will configure automatically${NC}" >&3
        else
            echo -e "${YELLOW}⚠️ No token provided - NordVPN will be installed but require manual login${NC}" >&3
        fi
    fi
}

# System preparation functions (stubs)
run_system_updates() {
    log "Running system updates"
    echo -e "${CYAN}📦 Running system updates...${NC}" >&3
    
    # Call external system updates script
    if [[ -f "$INSTALLERS_DIR/system_updates.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/system_updates.sh"
        "$INSTALLERS_DIR/system_updates.sh"
    else
        echo -e "${YELLOW}⚠️ system_updates.sh not found - using stub${NC}" >&3
        sleep 2
    fi
    
    log "System updates completed"
}

create_filesystem_structure() {
    log "Creating filesystem structure"
    echo -e "${CYAN}📁 Creating filesystem structure...${NC}" >&3
    
    # Call external filesystem setup script
    if [[ -f "$INSTALLERS_DIR/filesystem_setup.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/filesystem_setup.sh"
        "$INSTALLERS_DIR/filesystem_setup.sh"
    else
        echo -e "${YELLOW}⚠️ filesystem_setup.sh not found - using stub${NC}" >&3
        sleep 2
    fi
    
    log "Filesystem structure creation completed"
}

disable_default_motd() {
    log "Disabling default MOTD"
    echo -e "${CYAN}🔇 Disabling default MOTD...${NC}" >&3
    
    # Disable default Ubuntu MOTD components
    sudo chmod -x /etc/update-motd.d/* 2>/dev/null || true
    
    # Create empty motd file to override default
    sudo touch /etc/motd
    sudo chmod 644 /etc/motd
    
    # Clear existing dynamic motd
    sudo truncate -s 0 /var/run/motd.dynamic 2>/dev/null || true
    
    log "Default MOTD disabled"
}

setup_custom_motd() {
    log "Setting up custom MOTD system"
    echo -e "${CYAN}🎨 Setting up custom MOTD system...${NC}" >&3
    
    if [[ -f "$INSTALLERS_DIR/motd_setup.sh" ]]; then
        # Create permanent installation directory
        mkdir -p /opt/wawyc
        
        # Copy entire MOTD system to permanent location
        echo -e "${CYAN}📁 Installing MOTD files to /opt/wawyc...${NC}" >&3
        cp -r "$SCRIPT_DIR"/* /opt/wawyc/
        chmod +x /opt/wawyc/installers/motd_setup.sh
        
        # Ensure MOTD files are readable
        chmod 644 /opt/wawyc/MOTD/motd-banner.txt 2>/dev/null || true
        chmod 644 /opt/wawyc/MOTD/motd-quotes.txt 2>/dev/null || true
        
        # Create SSH login MOTD hook
        echo -e "${CYAN}🔗 Configuring SSH login integration...${NC}" >&3
        cat > /etc/profile.d/00-wawyc-motd.sh << 'EOF'
#!/bin/bash
# WAWYC Custom MOTD - SSH Login Integration
# This runs on every SSH login to display server status

# Only run for interactive SSH sessions
if [[ -n "$SSH_CONNECTION" ]] && [[ $- == *i* ]]; then
    if [[ -f "/opt/wawyc/installers/motd_setup.sh" ]]; then
        /opt/wawyc/installers/motd_setup.sh
    fi
fi
EOF
        chmod +x /etc/profile.d/00-wawyc-motd.sh
        
        # Create manual motd command for local use
        echo -e "${CYAN}⚡ Creating 'motd' command shortcut...${NC}" >&3
        cat > /usr/local/bin/motd << 'EOF'
#!/bin/bash
# WAWYC MOTD Manual Display Command
if [[ -f "/opt/wawyc/installers/motd_setup.sh" ]]; then
    /opt/wawyc/installers/motd_setup.sh
else
    echo "WAWYC MOTD system not installed"
fi
EOF
        chmod +x /usr/local/bin/motd
        
        # Create systemd service for MOTD updates (optional)
        echo -e "${CYAN}🔄 Creating MOTD update service...${NC}" >&3
        cat > /etc/systemd/system/wawyc-motd-update.service << 'EOF'
[Unit]
Description=Update WAWYC MOTD Cache
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/wawyc/installers/motd_setup.sh
User=root
StandardOutput=null

[Install]
WantedBy=multi-user.target
EOF
        
        # Create timer for periodic MOTD updates
        cat > /etc/systemd/system/wawyc-motd-update.timer << 'EOF'
[Unit]
Description=Update WAWYC MOTD every 5 minutes
Requires=wawyc-motd-update.service

[Timer]
OnBootSec=30sec
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF
        
        # Enable the timer (optional background updates)
        systemctl daemon-reload
        systemctl enable wawyc-motd-update.timer 2>/dev/null || true
        systemctl start wawyc-motd-update.timer 2>/dev/null || true
        
        echo -e "${GREEN}✅ Custom MOTD system installed successfully${NC}" >&3
        echo -e "${WHITE}   • SSH login integration: ${CYAN}Enabled${NC}" >&3
        echo -e "${WHITE}   • Manual command: ${CYAN}'motd'${NC}" >&3
        echo -e "${WHITE}   • Auto-updates: ${CYAN}Every 5 minutes${NC}" >&3
        
    else
        echo -e "${YELLOW}⚠️ motd_setup.sh not found - custom MOTD not configured${NC}" >&3
    fi
    
    log "Custom MOTD system configuration completed"
}

# Service installation functions (call external scripts)
install_samba() {
    log "Installing Samba file server"
    if [[ -f "$INSTALLERS_DIR/samba_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/samba_install.sh"
        if "$INSTALLERS_DIR/samba_install.sh"; then
            INSTALL_RESULTS[samba]="success"
            log "Samba installation completed successfully"
        else
            INSTALL_RESULTS[samba]="failed"
            INSTALL_ERRORS[samba]="Installation script failed"
            echo -e "${RED}❌ Samba installation failed - continuing with other services${NC}" >&3
            log "Samba installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[samba]="missing"
        INSTALL_ERRORS[samba]="Installer script not found"
        echo -e "${YELLOW}⚠️ samba_install.sh not found - service not installed${NC}" >&3
    fi
}

install_nordvpn() {
    log "Installing NordVPN client"
    if [[ -f "$INSTALLERS_DIR/nordvpn_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/nordvpn_install.sh"
        if "$INSTALLERS_DIR/nordvpn_install.sh"; then
            INSTALL_RESULTS[nordvpn]="success"
            log "NordVPN installation completed successfully"
        else
            INSTALL_RESULTS[nordvpn]="failed"
            INSTALL_ERRORS[nordvpn]="Installation script failed"
            echo -e "${RED}❌ NordVPN installation failed - continuing with other services${NC}" >&3
            log "NordVPN installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[nordvpn]="missing"
        INSTALL_ERRORS[nordvpn]="Installer script not found"
        echo -e "${YELLOW}⚠️ nordvpn_install.sh not found - service not installed${NC}" >&3
    fi
}

install_radarr() {
    log "Installing Radarr movie manager"
    if [[ -f "$INSTALLERS_DIR/radarr_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/radarr_install.sh"
        if "$INSTALLERS_DIR/radarr_install.sh"; then
            INSTALL_RESULTS[radarr]="success"
            log "Radarr installation completed successfully"
        else
            INSTALL_RESULTS[radarr]="failed"
            INSTALL_ERRORS[radarr]="Installation script failed"
            echo -e "${RED}❌ Radarr installation failed - continuing with other services${NC}" >&3
            log "Radarr installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[radarr]="missing"
        INSTALL_ERRORS[radarr]="Installer script not found"
        echo -e "${YELLOW}⚠️ radarr_install.sh not found - service not installed${NC}" >&3
    fi
}

install_prowlarr() {
    log "Installing Prowlarr indexer manager"
    if [[ -f "$INSTALLERS_DIR/prowlarr_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/prowlarr_install.sh"
        if "$INSTALLERS_DIR/prowlarr_install.sh"; then
            INSTALL_RESULTS[prowlarr]="success"
            log "Prowlarr installation completed successfully"
        else
            INSTALL_RESULTS[prowlarr]="failed"
            INSTALL_ERRORS[prowlarr]="Installation script failed"
            echo -e "${RED}❌ Prowlarr installation failed - continuing with other services${NC}" >&3
            log "Prowlarr installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[prowlarr]="missing"
        INSTALL_ERRORS[prowlarr]="Installer script not found"
        echo -e "${YELLOW}⚠️ prowlarr_install.sh not found - service not installed${NC}" >&3
    fi
}

install_sonarr() {
    log "Installing Sonarr TV manager"
    if [[ -f "$INSTALLERS_DIR/sonarr_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/sonarr_install.sh"
        if "$INSTALLERS_DIR/sonarr_install.sh"; then
            INSTALL_RESULTS[sonarr]="success"
            log "Sonarr installation completed successfully"
        else
            INSTALL_RESULTS[sonarr]="failed"
            INSTALL_ERRORS[sonarr]="Installation script failed"
            echo -e "${RED}❌ Sonarr installation failed - continuing with other services${NC}" >&3
            log "Sonarr installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[sonarr]="missing"
        INSTALL_ERRORS[sonarr]="Installer script not found"
        echo -e "${YELLOW}⚠️ sonarr_install.sh not found - service not installed${NC}" >&3
    fi
}

install_plex() {
    log "Installing Plex Media Server"
    if [[ -f "$INSTALLERS_DIR/plex_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/plex_install.sh"
        if "$INSTALLERS_DIR/plex_install.sh"; then
            INSTALL_RESULTS[plex]="success"
            log "Plex installation completed successfully"
        else
            INSTALL_RESULTS[plex]="failed"
            INSTALL_ERRORS[plex]="Installation script failed"
            echo -e "${RED}❌ Plex installation failed - continuing with other services${NC}" >&3
            log "Plex installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[plex]="missing"
        INSTALL_ERRORS[plex]="Installer script not found"
        echo -e "${YELLOW}⚠️ plex_install.sh not found - service not installed${NC}" >&3
    fi
}

install_overseerr() {
    log "Installing Overseerr request manager"
    if [[ -f "$INSTALLERS_DIR/overseerr_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/overseerr_install.sh"
        if "$INSTALLERS_DIR/overseerr_install.sh"; then
            INSTALL_RESULTS[overseerr]="success"
            log "Overseerr installation completed successfully"
        else
            INSTALL_RESULTS[overseerr]="failed"
            INSTALL_ERRORS[overseerr]="Installation script failed"
            echo -e "${RED}❌ Overseerr installation failed - continuing with other services${NC}" >&3
            log "Overseerr installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[overseerr]="missing"
        INSTALL_ERRORS[overseerr]="Installer script not found"
        echo -e "${YELLOW}⚠️ overseerr_install.sh not found - service not installed${NC}" >&3
    fi
}

install_qbittorrent() {
    log "Installing qBittorrent torrent client"
    if [[ -f "$INSTALLERS_DIR/qbittorrent_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/qbittorrent_install.sh"
        if "$INSTALLERS_DIR/qbittorrent_install.sh"; then
            INSTALL_RESULTS[qbittorrent]="success"
            log "qBittorrent installation completed successfully"
        else
            INSTALL_RESULTS[qbittorrent]="failed"
            INSTALL_ERRORS[qbittorrent]="Installation script failed"
            echo -e "${RED}❌ qBittorrent installation failed - continuing with other services${NC}" >&3
            log "qBittorrent installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[qbittorrent]="missing"
        INSTALL_ERRORS[qbittorrent]="Installer script not found"
        echo -e "${YELLOW}⚠️ qbittorrent_install.sh not found - service not installed${NC}" >&3
    fi
}

install_unpackerr() {
    log "Installing Unpackerr archive extractor"
    if [[ -f "$INSTALLERS_DIR/unpackerr_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/unpackerr_install.sh"
        if "$INSTALLERS_DIR/unpackerr_install.sh"; then
            INSTALL_RESULTS[unpackerr]="success"
            log "Unpackerr installation completed successfully"
        else
            INSTALL_RESULTS[unpackerr]="failed"
            INSTALL_ERRORS[unpackerr]="Installation script failed"
            echo -e "${RED}❌ Unpackerr installation failed - continuing with other services${NC}" >&3
            log "Unpackerr installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[unpackerr]="missing"
        INSTALL_ERRORS[unpackerr]="Installer script not found"
        echo -e "${YELLOW}⚠️ unpackerr_install.sh not found - service not installed${NC}" >&3
    fi
}

install_prometheus() {
    log "Installing Prometheus monitoring system"
    if [[ -f "$INSTALLERS_DIR/prometheus_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/prometheus_install.sh"
        if "$INSTALLERS_DIR/prometheus_install.sh"; then
            INSTALL_RESULTS[prometheus]="success"
            log "Prometheus installation completed successfully"
        else
            INSTALL_RESULTS[prometheus]="failed"
            INSTALL_ERRORS[prometheus]="Installation script failed"
            echo -e "${RED}❌ Prometheus installation failed - continuing with other services${NC}" >&3
            log "Prometheus installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[prometheus]="missing"
        INSTALL_ERRORS[prometheus]="Installer script not found"
        echo -e "${YELLOW}⚠️ prometheus_install.sh not found - service not installed${NC}" >&3
    fi
}

install_dashboard() {
    log "Installing Web Dashboard"
    if [[ -f "$INSTALLERS_DIR/dashboard_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/dashboard_install.sh"
        if "$INSTALLERS_DIR/dashboard_install.sh"; then
            INSTALL_RESULTS[dashboard]="success"
            log "Dashboard installation completed successfully"
        else
            INSTALL_RESULTS[dashboard]="failed"
            INSTALL_ERRORS[dashboard]="Installation script failed"
            echo -e "${RED}❌ Dashboard installation failed - continuing with other services${NC}" >&3
            log "Dashboard installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[dashboard]="missing"
        INSTALL_ERRORS[dashboard]="Installer script not found"
        echo -e "${YELLOW}⚠️ dashboard_install.sh not found - service not installed${NC}" >&3
    fi
}

install_gui() {
    log "Installing Ubuntu Desktop GUI"
    if [[ -f "$INSTALLERS_DIR/gui_install.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/gui_install.sh"
        if "$INSTALLERS_DIR/gui_install.sh"; then
            INSTALL_RESULTS[gui]="success"
            log "GUI installation completed successfully"
        else
            INSTALL_RESULTS[gui]="failed"
            INSTALL_ERRORS[gui]="Installation script failed"
            echo -e "${RED}❌ GUI installation failed - continuing with other services${NC}" >&3
            log "GUI installation failed but continuing"
        fi
    else
        INSTALL_RESULTS[gui]="missing"
        INSTALL_ERRORS[gui]="Installer script not found"
        echo -e "${YELLOW}⚠️ gui_install.sh not found - service not installed${NC}" >&3
    fi
}

# Get internal IP address (excluding VPN interfaces) - Enhanced WAWYC Method
get_internal_ip() {
    # Enhanced method to avoid VPN IPs and get true local network IP (from MOTD)
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

# Service status checking function
show_service_status() {
    local server_ip=$(get_internal_ip)
    
    print_fancy_box "🌐 SERVICE STATUS & ACCESS INFORMATION" "${CYAN}"
    echo ""
    
    # Show status for installed services based on WAWYC setup
    if [[ "${INSTALL_FLAGS[samba]}" == "true" ]]; then
        echo -e "  ${GREEN}●${NC} ${WHITE}Samba File Share:${NC}    \\\\\\\\$server_ip\\\\sambashare ${GREEN}[READY]${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[radarr]}" == "true" ]]; then
        echo -e "  ${GREEN}●${NC} ${WHITE}Radarr (Movies):${NC}     http://$server_ip:7878 ${GREEN}[READY]${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[prowlarr]}" == "true" ]]; then
        echo -e "  ${GREEN}●${NC} ${WHITE}Prowlarr (Indexers):${NC} http://$server_ip:9696 ${GREEN}[READY]${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[sonarr]}" == "true" ]]; then
        echo -e "  ${GREEN}●${NC} ${WHITE}Sonarr (TV):${NC}         http://$server_ip:8989 ${GREEN}[READY]${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[plex]}" == "true" ]]; then
        echo -e "  ${GREEN}●${NC} ${WHITE}Plex Media Server:${NC}   http://$server_ip:32400/web ${GREEN}[READY]${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[overseerr]}" == "true" ]]; then
        echo -e "  ${GREEN}●${NC} ${WHITE}Overseerr (Requests):${NC} http://$server_ip:5055 ${GREEN}[READY]${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[qbittorrent]}" == "true" ]]; then
        echo -e "  ${GREEN}●${NC} ${WHITE}qBittorrent:${NC}         http://$server_ip:8080 ${GREEN}[READY]${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[nordvpn]}" == "true" ]]; then
        echo -e "  ${BLUE}●${NC} ${WHITE}NordVPN:${NC}             ${YELLOW}Token login required${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[unpackerr]}" == "true" ]]; then
        echo -e "  ${BLUE}●${NC} ${WHITE}Unpackerr:${NC}           ${YELLOW}Background service - runs automatically${NC}" >&3
    fi
    
    if [[ "${INSTALL_FLAGS[gui]}" == "true" ]]; then
        echo -e "  ${PURPLE}●${NC} ${WHITE}Desktop GUI:${NC}         ${YELLOW}Installed - will activate on next reboot${NC}" >&3
    fi
}

show_installation_summary() {
    local success_count=0
    local failed_count=0
    local missing_count=0
    
    # Count results
    for service in "${!INSTALL_FLAGS[@]}"; do
        case "${INSTALL_RESULTS[$service]}" in
            "success") ((success_count++)) ;;
            "failed") ((failed_count++)) ;;
            "missing") ((missing_count++)) ;;
        esac
    done
    
    echo "" >&3
    if [[ $failed_count -eq 0 && $missing_count -eq 0 ]]; then
        print_fancy_box "🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉" "${GREEN}"
    else
        print_fancy_box "📊 INSTALLATION COMPLETED WITH MIXED RESULTS" "${YELLOW}"
    fi
    echo "" >&3
    
    # Show detailed results
    echo -e "${CYAN}${BOLD}📈 INSTALLATION SUMMARY:${NC}" >&3
    echo -e "${WHITE}   ✅ Successful: ${GREEN}$success_count${NC}" >&3
    echo -e "${WHITE}   ❌ Failed: ${RED}$failed_count${NC}" >&3  
    echo -e "${WHITE}   ⚠️  Missing: ${YELLOW}$missing_count${NC}" >&3
    echo "" >&3
    
    # Show service-by-service results
    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}✅ SUCCESSFULLY INSTALLED:${NC}" >&3
        for service in "${!INSTALL_FLAGS[@]}"; do
            if [[ "${INSTALL_RESULTS[$service]}" == "success" ]]; then
                echo -e "  ${GREEN}●${NC} ${SERVICE_DESCRIPTIONS[$(get_service_key "$service")]}" >&3
            fi
        done
        echo "" >&3
    fi
    
    if [[ $failed_count -gt 0 ]]; then
        echo -e "${RED}${BOLD}❌ FAILED INSTALLATIONS:${NC}" >&3
        for service in "${!INSTALL_FLAGS[@]}"; do
            if [[ "${INSTALL_RESULTS[$service]}" == "failed" ]]; then
                echo -e "  ${RED}●${NC} ${SERVICE_DESCRIPTIONS[$(get_service_key "$service")]} - ${INSTALL_ERRORS[$service]}" >&3
            fi
        done
        echo "" >&3
    fi
    
    if [[ $missing_count -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}⚠️  MISSING INSTALLERS:${NC}" >&3
        for service in "${!INSTALL_FLAGS[@]}"; do
            if [[ "${INSTALL_RESULTS[$service]}" == "missing" ]]; then
                echo -e "  ${YELLOW}●${NC} ${SERVICE_DESCRIPTIONS[$(get_service_key "$service")]} - ${INSTALL_ERRORS[$service]}" >&3
            fi
        done
        echo "" >&3
    fi
    
    echo -e "${WHITE}${BOLD}📁 Log file location: ${CYAN}$LOG_FILE${NC}" >&3
    echo -e "${WHITE}${BOLD}📁 Configuration files: ${CYAN}$CONFIG_DIR${NC}" >&3
    echo "" >&3
    
    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}✨ Your WAWYC media server has $success_count services ready! ✨${NC}" >&3
        if [[ $failed_count -gt 0 ]]; then
            echo -e "${YELLOW}💡 Failed services can be retried by running individual installers${NC}" >&3
        fi
    else
        echo -e "${RED}${BOLD}⚠️  No services were successfully installed${NC}" >&3
        echo -e "${YELLOW}💡 Check the log file for details: $LOG_FILE${NC}" >&3
    fi
    echo "" >&3
}

# Helper function to get service key from service name
get_service_key() {
    local service_name="$1"
    for key in "${!SERVICES[@]}"; do
        if [[ "${SERVICES[$key]}" == "$service_name" ]]; then
            echo "$key"
            return 0
        fi
    done
    echo "unknown"
}

show_completion() {
    show_installation_summary
    
    # Always try to display the custom MOTD (even if some services failed)
    echo -e "${CYAN}${BOLD}📊 Updating system status display...${NC}" >&3
    if [[ -f "$INSTALLERS_DIR/motd_setup.sh" ]]; then
        chmod +x "$INSTALLERS_DIR/motd_setup.sh"
        if "$INSTALLERS_DIR/motd_setup.sh"; then
            echo -e "${GREEN}✅ MOTD updated successfully${NC}" >&3
        else
            echo -e "${YELLOW}⚠️  MOTD update had issues but system is functional${NC}" >&3
        fi
    else
        echo -e "${YELLOW}⚠️  MOTD system not available${NC}" >&3
    fi
}

# Main installation orchestration
main() {
    print_header
    check_root
    test_connectivity
    
    # Service selection
    show_service_menu
    read -r selection
    
    # Parse selection with error handling
    if ! parse_selection "$selection"; then
        echo -e "${RED}❌ Invalid selection. Please try again.${NC}" >&3
        exit 1
    fi
    
    echo ""
    print_fancy_box "🚀 STARTING INSTALLATION PROCESS" "${PURPLE}"
    echo ""
    
    # System preparation (always performed)
    run_system_updates
    create_filesystem_structure
    disable_default_motd
    setup_custom_motd
    
    # Install selected services in optimal order per WAWYC instructions
    echo ""
    print_fancy_box "📦 INSTALLING SELECTED SERVICES" "${CYAN}"
    echo ""
    
    [[ "${INSTALL_FLAGS[samba]}" == "true" ]] && install_samba
    [[ "${INSTALL_FLAGS[nordvpn]}" == "true" ]] && install_nordvpn
    [[ "${INSTALL_FLAGS[radarr]}" == "true" ]] && install_radarr
    [[ "${INSTALL_FLAGS[prowlarr]}" == "true" ]] && install_prowlarr
    [[ "${INSTALL_FLAGS[sonarr]}" == "true" ]] && install_sonarr
    [[ "${INSTALL_FLAGS[plex]}" == "true" ]] && install_plex
    [[ "${INSTALL_FLAGS[overseerr]}" == "true" ]] && install_overseerr
    [[ "${INSTALL_FLAGS[unpackerr]}" == "true" ]] && install_unpackerr
    [[ "${INSTALL_FLAGS[prometheus]}" == "true" ]] && install_prometheus
    [[ "${INSTALL_FLAGS[dashboard]}" == "true" ]] && install_dashboard
    [[ "${INSTALL_FLAGS[gui]}" == "true" ]] && install_gui
    
    # qBittorrent installed last as per best practices
    [[ "${INSTALL_FLAGS[qbittorrent]}" == "true" ]] && install_qbittorrent
    
    # Show final status
    show_completion
    
    log "WAWYC media server installation process completed successfully"
}

# Execute main function
main "$@"
