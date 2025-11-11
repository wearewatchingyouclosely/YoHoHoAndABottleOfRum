#!/bin/bash
# Sonarr Installation Script
# Based on WAWYC instructions using official Sonarr install script

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

# Check if Sonarr is already installed and running
if systemctl is-active --quiet sonarr 2>/dev/null; then
    echo -e "${GREEN}✅ Sonarr is already installed and running${NC}"
    echo -e "${BLUE}ℹ️  Access via http://$(hostname -I | awk '{print $1}'):8989${NC}"
    echo -e "${YELLOW}⚠️  Skipping installation (service already active)${NC}"
    exit 0
fi

echo -e "${CYAN}📺 Installing Sonarr (WAWYC Method)...${NC}"

# Sonarr installation using automated approach (WAWYC method)
echo -e "${YELLOW}  → Installing Sonarr automatically with WAWYC defaults${NC}"

# Set variables for Sonarr (matching WAWYC setup)
app="sonarr"
app_port="8989"
app_prereq="curl sqlite3 wget"
app_umask="0002"
branch="main"
installdir="/opt"
bindir="${installdir}/${app^}"
datadir="/var/lib/$app/"
app_bin=${app^}
app_uid="$app"
app_guid="media"

# Install prerequisites
echo -e "${YELLOW}  → Installing prerequisites${NC}"
apt update
apt install $app_prereq -y

# Create user and group
echo -e "${YELLOW}  → Creating sonarr user and setting up groups${NC}"
if ! getent group "$app_guid" >/dev/null; then
    groupadd "$app_guid"
fi
if ! getent passwd "$app_uid" >/dev/null; then
    adduser --system --no-create-home --ingroup "$app_guid" "$app_uid"
fi
if ! getent group "$app_guid" | grep -qw "$app_uid"; then
    usermod -a -G "$app_guid" "$app_uid"
fi

# Stop existing service if running
if systemctl is-active --quiet "$app" 2>/dev/null; then
    systemctl stop "$app"
    systemctl disable "$app".service
fi

# Create directories
echo -e "${YELLOW}  → Creating application directories${NC}"
mkdir -p "$datadir"
chown -R "$app_uid":"$app_guid" "$datadir"
chmod 775 "$datadir"

# Download and install Sonarr
echo -e "${YELLOW}  → Downloading Sonarr${NC}"
ARCH=$(dpkg --print-architecture)
dlbase="https://services.sonarr.tv/v1/download/$branch/latest?version=4&os=linux"
case "$ARCH" in
"amd64") DLURL="${dlbase}&arch=x64" ;;
"armhf") DLURL="${dlbase}&arch=arm" ;;
"arm64") DLURL="${dlbase}&arch=arm64" ;;
*)
    echo -e "${RED}❌ Architecture $ARCH not supported${NC}"
    exit 1
    ;;
esac

# Clean up old downloads and download new
rm -f "${app^}".*.tar.gz
if ! wget --content-disposition "$DLURL"; then
    echo -e "${RED}❌ Failed to download Sonarr${NC}"
    exit 1
fi

echo -e "${YELLOW}  → Extracting and installing Sonarr${NC}"
tar -xzf "${app^}".*.tar.gz
rm -rf "$bindir"
mv "${app^}" $installdir
chown "$app_uid":"$app_guid" -R "$bindir"
chmod 775 "$bindir"

# Create update marker
touch "$datadir"/update_required
chown "$app_uid":"$app_guid" "$datadir"/update_required

# Clean up
rm -f "${app^}".*.tar.gz

echo -e "${GREEN}✓ Sonarr installation completed${NC}"

# Create systemd service
echo -e "${YELLOW}  → Creating Sonarr systemd service${NC}"
rm -f /etc/systemd/system/"$app".service

cat > /etc/systemd/system/"$app".service << EOF
[Unit]
Description=${app^} Daemon
After=syslog.target network.target
[Service]
User=$app_uid
Group=$app_guid
UMask=$app_umask
Type=simple
ExecStart=$bindir/$app_bin -nobrowser -data=$datadir
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

# Start Sonarr service
echo -e "${YELLOW}  → Starting Sonarr service${NC}"
systemctl daemon-reload
systemctl enable sonarr
systemctl start sonarr

# Wait for service to start
sleep 5

# Check service status
if systemctl is-active --quiet sonarr; then
    echo -e "${GREEN}✓ Sonarr service started successfully${NC}"
else
    echo -e "${RED}❌ Sonarr service failed to start${NC}"
    systemctl status sonarr --no-pager
    exit 1
fi

# Get server IP for web interface (VPN-aware method)
get_server_ip() {
    local ip=""
    for interface in eth0 ens160 ens192 ens33 enp0s3 enp0s8 wlan0 wlp2s0; do
        ip=$(ip addr show "$interface" 2>/dev/null | grep -oP 'inet \K192\.168\.[0-9]+\.[0-9]+|inet \K10\.[0-9]+\.[0-9]+\.[0-9]+|inet \K172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+' | head -1)
        if [[ -n "$ip" ]]; then echo "$ip"; return 0; fi
    done
    for iface_ip in $(ip addr show | grep -E 'inet (192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | grep -v 'inet 127\.' | awk '{print $2}' | cut -d'/' -f1); do
        local iface=$(ip addr show | grep "$iface_ip" | grep -oP '^\d+: \K[^:]+' | head -1)
        if [[ ! "$iface" =~ ^(nordlynx|tun|tap|ppp|wg) ]]; then echo "$iface_ip"; return 0; fi
    done
    ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+' || hostname -I | awk '{print $1}')
    echo "${ip:-127.0.0.1}"
}

SERVER_IP=$(get_server_ip)

echo ""
echo -e "${GREEN}✅ Sonarr installation completed successfully!${NC}"
echo ""
echo -e "${CYAN}🌐 Web Interface Access:${NC}"
echo -e "${WHITE}   URL: ${BLUE}http://$SERVER_IP:8989${NC}"
echo ""
echo -e "${BLUE}📖 Configuration Recommendations:${NC}"
echo -e "${WHITE}   • Media folder: ${CYAN}/srv/serverFilesystem/media/tv${NC}"
echo -e "${WHITE}   • Downloads folder: ${CYAN}/srv/serverFilesystem/downloads${NC}"
echo -e "${WHITE}   • Connect to Prowlarr for indexers${NC}"
echo -e "${WHITE}   • Connect to qBittorrent as download client${NC}"