#!/bin/bash
# Troubleshoot Prometheus and Dashboard Services

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}🔍 Troubleshooting Failed Services${NC}"
echo -e "${WHITE}═══════════════════════════════════════${NC}"
echo ""

# Check Prometheus
echo -e "${YELLOW}📊 Prometheus Service Status:${NC}"
if systemctl is-active --quiet prometheus 2>/dev/null; then
    echo -e "${GREEN}  ✓ Service is running${NC}"
else
    echo -e "${RED}  ✗ Service is not running${NC}"
    echo -e "${BLUE}    Checking if installed...${NC}"
    if systemctl list-unit-files prometheus.service >/dev/null 2>&1; then
        echo -e "${YELLOW}    Service exists but not running${NC}"
        echo -e "${WHITE}    Status:${NC}"
        systemctl status prometheus --no-pager -l
        echo ""
        echo -e "${WHITE}    Recent logs:${NC}"
        journalctl -u prometheus --no-pager -l -n 10
    else
        echo -e "${RED}    ✗ Prometheus service not installed${NC}"
        echo -e "${CYAN}    💡 Run the installer: installers/prometheus_install.sh${NC}"
    fi
fi

echo ""
echo -e "${WHITE}═══════════════════════════════════════${NC}"

# Check Dashboard
echo -e "${YELLOW}🎨 Dashboard Service Status:${NC}"
if systemctl is-active --quiet media-dashboard 2>/dev/null; then
    echo -e "${GREEN}  ✓ Service is running${NC}"
else
    echo -e "${RED}  ✗ Service is not running${NC}"
    echo -e "${BLUE}    Checking if installed...${NC}"
    if systemctl list-unit-files media-dashboard.service >/dev/null 2>&1; then
        echo -e "${YELLOW}    Service exists but not running${NC}"
        echo -e "${WHITE}    Status:${NC}"
        systemctl status media-dashboard --no-pager -l
        echo ""
        echo -e "${WHITE}    Recent logs:${NC}"
        journalctl -u media-dashboard --no-pager -l -n 10
    else
        echo -e "${RED}    ✗ Dashboard service not installed${NC}"
        echo -e "${CYAN}    💡 Run the installer: installers/dashboard_install.sh${NC}"
    fi
fi

echo ""
echo -e "${WHITE}═══════════════════════════════════════${NC}"

# Check port availability
echo -e "${YELLOW}🔌 Port Availability Check:${NC}"
echo -e "${BLUE}  Checking port 9090 (Prometheus):${NC}"
if netstat -tlnp 2>/dev/null | grep -q ":9090 "; then
    echo -e "${GREEN}    ✓ Port 9090 is in use${NC}"
    netstat -tlnp 2>/dev/null | grep ":9090 "
else
    echo -e "${RED}    ✗ Port 9090 is not in use${NC}"
fi

echo -e "${BLUE}  Checking port 3000 (Dashboard):${NC}"
if netstat -tlnp 2>/dev/null | grep -q ":3000 "; then
    echo -e "${GREEN}    ✓ Port 3000 is in use${NC}"
    netstat -tlnp 2>/dev/null | grep ":3000 "
else
    echo -e "${RED}    ✗ Port 3000 is not in use${NC}"
fi

echo ""
echo -e "${WHITE}═══════════════════════════════════════${NC}"

# Check if files exist
echo -e "${YELLOW}📁 Installation Files Check:${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}  Prometheus installer:${NC}"
if [[ -f "$SCRIPT_DIR/prometheus_install.sh" ]]; then
    echo -e "${GREEN}    ✓ $SCRIPT_DIR/prometheus_install.sh${NC}"
else
    echo -e "${RED}    ✗ Prometheus installer not found${NC}"
fi

echo -e "${BLUE}  Dashboard installer:${NC}"
if [[ -f "$SCRIPT_DIR/dashboard_install.sh" ]]; then
    echo -e "${GREEN}    ✓ $SCRIPT_DIR/dashboard_install.sh${NC}"
else
    echo -e "${RED}    ✗ Dashboard installer not found${NC}"
fi

echo -e "${BLUE}  Dashboard files:${NC}"
if [[ -d "$SCRIPT_DIR/../dashboard" ]]; then
    echo -e "${GREEN}    ✓ Dashboard directory exists${NC}"
    if [[ -f "$SCRIPT_DIR/../dashboard/server_dashboard.py" ]]; then
        echo -e "${GREEN}    ✓ Python server file exists${NC}"
    else
        echo -e "${RED}    ✗ server_dashboard.py missing${NC}"
    fi
    if [[ -f "$SCRIPT_DIR/../dashboard/templates/dashboard.html" ]]; then
        echo -e "${GREEN}    ✓ HTML template exists${NC}"
    else
        echo -e "${RED}    ✗ dashboard.html template missing${NC}"
    fi
else
    echo -e "${RED}    ✗ Dashboard directory not found${NC}"
fi

echo ""
echo -e "${WHITE}═══════════════════════════════════════${NC}"

# Quick fix suggestions
echo -e "${CYAN}🛠️  Quick Fix Suggestions:${NC}"
echo ""

if ! systemctl is-active --quiet prometheus 2>/dev/null; then
    if systemctl list-unit-files prometheus.service >/dev/null 2>&1; then
        echo -e "${YELLOW}📊 Prometheus - Try restarting:${NC}"
        echo -e "${WHITE}    sudo systemctl restart prometheus${NC}"
        echo -e "${WHITE}    sudo systemctl status prometheus${NC}"
    else
        echo -e "${YELLOW}📊 Prometheus - Install:${NC}"
        echo -e "${WHITE}    sudo bash $SCRIPT_DIR/prometheus_install.sh${NC}"
    fi
    echo ""
fi

if ! systemctl is-active --quiet media-dashboard 2>/dev/null; then
    if systemctl list-unit-files media-dashboard.service >/dev/null 2>&1; then
        echo -e "${YELLOW}🎨 Dashboard - Try restarting:${NC}"
        echo -e "${WHITE}    sudo systemctl restart media-dashboard${NC}"
        echo -e "${WHITE}    sudo systemctl status media-dashboard${NC}"
    else
        echo -e "${YELLOW}🎨 Dashboard - Install:${NC}"
        echo -e "${WHITE}    sudo bash $SCRIPT_DIR/dashboard_install.sh${NC}"
    fi
    echo ""
fi

echo -e "${BLUE}🔄 After fixes, refresh MOTD:${NC}"
echo -e "${WHITE}    sudo bash $SCRIPT_DIR/motd_setup.sh${NC}"

echo ""
echo -e "${CYAN}💡 Need help? Check logs with:${NC}"
echo -e "${WHITE}    journalctl -u prometheus -f    (for Prometheus)${NC}"
echo -e "${WHITE}    journalctl -u media-dashboard -f    (for Dashboard)${NC}"