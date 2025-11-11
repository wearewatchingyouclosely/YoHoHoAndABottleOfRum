#!/bin/bash
# Prowlarr Installation Script
# Based on WAWYC instructions using official servarr install methods

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

SERVICE_NAME="prowlarr"

# Check if Prowlarr is already installed and running
if systemctl is-active --quiet prowlarr 2>/dev/null; then
    echo -e "${GREEN}✅ Prowlarr is already installed and running${NC}"
    echo -e "${BLUE}ℹ️  Access via http://$(hostname -I | awk '{print $1}'):9696${NC}"
    echo -e "${YELLOW}⚠️  Skipping installation (service already active)${NC}"
    exit 0
fi

echo -e "${CYAN}🔍 Installing Prowlarr (WAWYC Method)...${NC}"

# Prowlarr installation using automated approach (WAWYC method)
echo -e "${YELLOW}  → Installing Prowlarr automatically${NC}"

# Set variables for Prowlarr
app="prowlarr"
app_port="9696"
app_prereq="curl sqlite3"
app_umask="0002"
branch="master"
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
echo -e "${YELLOW}  → Creating prowlarr user and setting up groups${NC}"
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

# Download and install Prowlarr
echo -e "${YELLOW}  → Downloading Prowlarr${NC}"
ARCH=$(dpkg --print-architecture)
dlbase="https://$app.servarr.com/v1/update/$branch/updatefile?os=linux&runtime=netcore"
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
    echo -e "${RED}❌ Failed to download Prowlarr${NC}"
    exit 1
fi

echo -e "${YELLOW}  → Extracting and installing Prowlarr${NC}"
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

echo -e "${GREEN}✓ Prowlarr installation completed${NC}"

# Create systemd service
echo -e "${YELLOW}  → Creating Prowlarr systemd service${NC}"
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

# Start Prowlarr service
echo -e "${YELLOW}  → Starting Prowlarr service${NC}"
systemctl daemon-reload
systemctl enable prowlarr
systemctl start prowlarr

# Wait for service to start
sleep 5

# Check service status
if systemctl is-active --quiet prowlarr; then
    echo -e "${GREEN}✓ Prowlarr service started successfully${NC}"
else
    echo -e "${RED}❌ Prowlarr service failed to start${NC}"
    systemctl status prowlarr --no-pager
    exit 1
fi

# Get server IP
SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+' || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}✅ Prowlarr installation completed successfully!${NC}"
echo ""
echo -e "${CYAN}🌐 Web Interface Access:${NC}"
echo -e "${WHITE}   URL: ${BLUE}http://$SERVER_IP:9696${NC}"
echo ""
echo -e "${BLUE}📖 Configuration Recommendations:${NC}"
echo -e "${WHITE}   • Add your preferred indexers${NC}"
echo -e "${WHITE}   • Configure apps (Radarr, Sonarr) to sync indexers${NC}"
echo -e "${WHITE}   • Test indexer connectivity${NC}"