#!/bin/bash
# Network Monitoring Script for YoHoHoAndABottleOfRum
# Helps diagnose IP change issues in VM/testing environments

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
LOG_FILE="/var/log/network-monitor.log"
MONITOR_INTERVAL=30  # seconds

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Get current IP (same logic as dashboard)
get_current_ip() {
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

    # Method 3: Use hostname -I but filter out VPN ranges
    ip=$(hostname -I | tr ' ' '\n' | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | head -1)

    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi

    # Method 4: Last resort
    ip=$(hostname -I | awk '{print $1}')
    echo "${ip:-127.0.0.1}"
}

# Show current network status
show_network_status() {
    log "🌐 Network Status Report"

    # Get current IP
    current_ip=$(get_current_ip)
    log "📍 Current IP: $current_ip"

    # Show all interfaces
    log "🔌 Network Interfaces:"
    ip addr show | grep -E "^[0-9]+:|^    inet " | while read -r line; do
        if [[ $line =~ ^[0-9]+: ]]; then
            interface=$(echo "$line" | grep -oP '^\d+: \K[^:]+')
            log "  • $interface"
        elif [[ $line =~ "    inet " ]]; then
            ip_addr=$(echo "$line" | awk '{print $2}' | cut -d'/' -f1)
            if [[ "$ip_addr" == "$current_ip" ]]; then
                log "    └─ $ip_addr ⭐ (current)"
            else
                log "    └─ $ip_addr"
            fi
        fi
    done

    # Check DHCP lease (if applicable)
    log "📋 DHCP Information:"
    if command -v dhcpcd >/dev/null 2>&1; then
        dhcpcd -U 2>/dev/null | grep -E "(ip_address|subnet_mask|routers|domain_name_servers)" | sed 's/^/  /' || log "  No DHCP info available"
    else
        log "  DHCP client not available or not in use"
    fi

    # Check default route
    default_route=$(ip route show default 2>/dev/null | head -1)
    if [[ -n "$default_route" ]]; then
        log "🛣️ Default Route: $default_route"
    else
        log "❌ No default route found"
    fi

    echo "" >> "$LOG_FILE"
}

# Monitor for IP changes
monitor_ip_changes() {
    log "👀 Starting IP change monitoring (interval: ${MONITOR_INTERVAL}s)"
    log "Press Ctrl+C to stop monitoring"

    last_ip=$(get_current_ip)
    log "📍 Initial IP: $last_ip"

    while true; do
        sleep "$MONITOR_INTERVAL"
        current_ip=$(get_current_ip)

        if [[ "$current_ip" != "$last_ip" ]]; then
            log "🚨 IP CHANGE DETECTED!"
            log "  From: $last_ip"
            log "  To: $current_ip"
            show_network_status
            last_ip="$current_ip"
        fi
    done
}

# Main function
main() {
    case "${1:-status}" in
        "status")
            show_network_status
            ;;
        "monitor")
            monitor_ip_changes
            ;;
        "help"|"-h"|"--help")
            echo "Network Monitoring Script for YoHoHoAndABottleOfRum"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  status   Show current network status (default)"
            echo "  monitor  Monitor for IP changes continuously"
            echo "  help     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Show current status"
            echo "  $0 monitor           # Monitor for changes"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"