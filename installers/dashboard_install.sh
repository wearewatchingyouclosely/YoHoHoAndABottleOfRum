#!/bin/bash
# Dashboard Installation Script
# Creates a web-based dashboard replicating MOTD functionality

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

SERVICE_NAME="dashboard"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR/../dashboard"

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

# Check if Dashboard is already installed and running
if systemctl is-active --quiet media-dashboard 2>/dev/null; then
    SERVER_IP=$(get_internal_ip)
    echo -e "${GREEN}✅ Dashboard is already installed and running${NC}"
    echo -e "${BLUE}ℹ️  Access via http://$SERVER_IP:3000${NC}"
    echo -e "${YELLOW}⚠️  Skipping installation (service already active)${NC}"
    exit 0
elif systemctl list-unit-files media-dashboard.service >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Dashboard service exists but is not running${NC}"
    echo -e "${BLUE}ℹ️  Attempting to restart...${NC}"
    sudo systemctl restart media-dashboard
    sleep 3
    if systemctl is-active --quiet media-dashboard 2>/dev/null; then
        SERVER_IP=$(get_internal_ip)
        echo -e "${GREEN}✅ Dashboard successfully restarted${NC}"
        echo -e "${BLUE}ℹ️  Access via http://$SERVER_IP:3000${NC}"
        exit 0
    else
        echo -e "${RED}❌ Dashboard failed to restart, continuing with reinstallation...${NC}"
    fi
fi

echo -e "${CYAN}🎨 Installing Web Dashboard...${NC}"
echo -e "${BLUE}📱 Creating responsive web interface replicating MOTD functionality${NC}"

# Install Python dependencies
echo -e "${YELLOW}  → Installing Python dependencies${NC}"
sudo apt update
sudo apt install -y python3 python3-pip python3-venv python3-flask

# Verify pip3 is available
if ! command -v pip3 >/dev/null 2>&1; then
    echo -e "${YELLOW}  → pip3 not found, trying alternative installation${NC}"
    sudo apt install -y python3-setuptools python3-wheel
    # Try to install pip manually if needed
    which python3-pip || sudo apt install -y python3-pip
fi

# Create dashboard user
echo -e "${YELLOW}  → Creating dashboard user${NC}"
sudo useradd --system --shell /bin/false --home /opt/dashboard dashboard 2>/dev/null || echo "User dashboard already exists"

# Create directories
echo -e "${YELLOW}  → Setting up directories${NC}"
sudo mkdir -p /opt/dashboard
sudo rm -rf /opt/dashboard/*
sudo cp -r "$DASHBOARD_DIR"/* /opt/dashboard/

# Copy MOTD quotes file for dashboard
echo -e "${YELLOW}  → Copying MOTD quotes for dashboard${NC}"
sudo mkdir -p /opt/dashboard/MOTD
sudo cp "$SCRIPT_DIR/../MOTD/motd-quotes.txt" /opt/dashboard/MOTD/ 2>/dev/null || echo "Quotes file not found, using fallback"

sudo chown -R dashboard:dashboard /opt/dashboard

# Create Python virtual environment and install requirements
echo -e "${YELLOW}  → Setting up Python environment${NC}"
sudo -u dashboard python3 -m venv /opt/dashboard/venv

# Check if venv was created successfully
if [[ ! -d "/opt/dashboard/venv" ]]; then
    echo -e "${RED}❌ Failed to create virtual environment${NC}"
    echo -e "${YELLOW}  Trying alternative approach...${NC}"
    sudo python3 -m venv /opt/dashboard/venv
    sudo chown -R dashboard:dashboard /opt/dashboard/venv
fi

echo -e "${YELLOW}  → Installing Python packages${NC}"
# Install both in venv and system-wide for maximum compatibility
sudo -u dashboard /opt/dashboard/venv/bin/pip install flask requests || echo "Virtual environment pip failed"
sudo apt install -y python3-flask python3-requests python3-urllib3 python3-certifi

echo -e "${YELLOW}  → Verifying installations${NC}"
sudo -u dashboard /opt/dashboard/venv/bin/python -c "import flask, requests; print('✅ Virtual env packages OK')" 2>/dev/null || echo "❌ Virtual env packages failed"
python3 -c "import flask, requests; print('✅ System packages OK')" 2>/dev/null || echo "❌ System packages failed"

# Create systemd service file
echo -e "${YELLOW}  → Creating systemd service${NC}"
# Create a wrapper script to handle Python environment
sudo tee /opt/dashboard/start_dashboard.sh > /dev/null <<'EOF'
#!/bin/bash
cd /opt/dashboard

# Try virtual environment first
if [[ -f "/opt/dashboard/venv/bin/python" ]]; then
    echo "🐍 Using virtual environment"
    source /opt/dashboard/venv/bin/activate
    exec python server_dashboard.py
else
    echo "🐍 Using system Python"
    export PYTHONPATH="/usr/lib/python3/dist-packages:/opt/dashboard:$PYTHONPATH"
    exec python3 server_dashboard.py
fi
EOF

sudo chmod +x /opt/dashboard/start_dashboard.sh
sudo chown dashboard:dashboard /opt/dashboard/start_dashboard.sh

sudo tee /etc/systemd/system/media-dashboard.service > /dev/null <<EOF
[Unit]
Description=Media Server Dashboard
After=network.target

[Service]
Type=simple
User=dashboard
Group=dashboard
WorkingDirectory=/opt/dashboard
ExecStart=/opt/dashboard/start_dashboard.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=media-dashboard

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the dashboard service
echo -e "${YELLOW}  → Enabling and starting dashboard service${NC}"
sudo systemctl daemon-reload
sudo systemctl enable media-dashboard
sudo systemctl start media-dashboard

# Wait for service to start and check status
echo -e "${YELLOW}  → Checking service status...${NC}"
sleep 5

if systemctl is-active --quiet media-dashboard; then
    SERVER_IP=$(get_internal_ip)
    
    echo ""
    echo -e "${GREEN}✅ Dashboard installation completed successfully!${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN} 🎨 Web Dashboard${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}📱 Web Interface: http://$SERVER_IP:3000${NC}"
    echo -e "${CYAN}📊 Auto-refresh: Every 30 seconds${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📱 Features:${NC}"
    echo -e "${WHITE}  • Responsive design for mobile, tablet, desktop${NC}"
    echo -e "${WHITE}  • Real-time service status monitoring${NC}"
    echo -e "${WHITE}  • System resource monitoring (CPU, RAM, disk)${NC}"
    echo -e "${WHITE}  • NordVPN connection status${NC}"
    echo -e "${WHITE}  • Direct links to all media services${NC}"
    echo -e "${WHITE}  • Slick, modern interface with animations${NC}"
    echo ""
    echo -e "${BLUE}📋 Usage:${NC}"
    echo -e "${WHITE}  • Access from any device on your network${NC}"
    echo -e "${WHITE}  • Click service names to open web interfaces${NC}"
    echo -e "${WHITE}  • Use refresh button for manual updates${NC}"
    echo -e "${WHITE}  • Perfect for mobile monitoring on-the-go${NC}"
    echo ""
    echo -e "${YELLOW}🎯 Bookmark http://$SERVER_IP:3000 for quick access!${NC}"
else
    echo -e "${RED}❌ Dashboard service failed to start properly${NC}"
    echo -e "${YELLOW}  Debugging installation...${NC}"
    
    echo -e "${CYAN}📁 Directory contents:${NC}"
    ls -la /opt/dashboard/ 2>/dev/null || echo "❌ /opt/dashboard not found"
    
    echo -e "${CYAN}🐍 Python environment:${NC}"
    ls -la /opt/dashboard/venv/bin/ 2>/dev/null || echo "❌ Virtual environment not found"
    
    echo -e "${CYAN}📋 Service status:${NC}"
    sudo systemctl status media-dashboard --no-pager -l
    
    echo -e "${CYAN}📊 Service logs:${NC}"
    sudo journalctl -u media-dashboard --no-pager -n 20
    
    echo -e "${CYAN}🔧 Manual test:${NC}"
    echo "Try running manually:"
    echo "cd /opt/dashboard && python3 server_dashboard.py"
    
    exit 1
fi