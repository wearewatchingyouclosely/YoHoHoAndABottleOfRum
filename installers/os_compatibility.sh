#!/bin/bash
# OS Detection and Compatibility Script
# Automatically chooses the right installer for the detected OS

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

get_installer_suffix() {
    local service=$1
    detect_os
    
    case "$OS" in
        "Ubuntu"*)
            echo ""  # Use default installers
            ;;
        "Debian"*)
            case "$service" in
                "nordvpn"|"overseerr")
                    echo "_debian"  # Use Debian-specific versions
                    ;;
                *)
                    echo ""  # Most work as-is
                    ;;
            esac
            ;;
        *)
            echo -e "\033[1;33m⚠️  Unsupported OS: $OS\033[0m"
            echo -e "\033[0;36mℹ️  This script is designed for Ubuntu/Debian\033[0m"
            echo ""
            ;;
    esac
}

# Usage: install_service servicename
install_service() {
    local service=$1
    local suffix=$(get_installer_suffix "$service")
    local installer="installers/${service}_install${suffix}.sh"
    
    if [[ -f "$installer" ]]; then
        echo -e "\033[0;36m🚀 Installing $service for $OS...\033[0m"
        bash "$installer"
    else
        echo -e "\033[1;31m❌ Installer not found: $installer\033[0m"
        exit 1
    fi
}

# Export functions for use in main script
export -f detect_os get_installer_suffix install_service