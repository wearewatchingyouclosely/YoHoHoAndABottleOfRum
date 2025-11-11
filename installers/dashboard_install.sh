# Ensure dashboard user is in nordvpn group for Snap CLI access
echo -e "${YELLOW}  → Adding dashboard user to nordvpn group${NC}"
sudo usermod -aG nordvpn dashboard 2>/dev/null || echo "Could not add dashboard user to nordvpn group"
# Commit History:
#   2025-10-12 19:14:14 -0400 | mitchell | f034589b | Update commit history in scripts for consistency and tracking
# ---

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


# Create dashboard user with home in /home/dashboard for Snap compatibility
echo -e "${YELLOW}  → Creating dashboard user with home /home/dashboard${NC}"
if id "dashboard" &>/dev/null; then
    sudo usermod -d /home/dashboard dashboard
else
    sudo useradd --system --shell /bin/false --home /home/dashboard dashboard
fi
sudo mkdir -p /home/dashboard
sudo chown dashboard:dashboard /home/dashboard


# Forcibly stop the dashboard service before overwriting files (idempotent)
echo -e "${YELLOW}  → Stopping dashboard service (if running)${NC}"
sudo systemctl stop media-dashboard.service 2>/dev/null || true



# Create dashboard app directory (still in /opt/dashboard)
echo -e "${YELLOW}  → Setting up dashboard app directory${NC}"
sudo mkdir -p /opt/dashboard
# Remove all files, including hidden ones — use safe removal and fallback
if [ -d /opt/dashboard ]; then
    sudo find /opt/dashboard -mindepth 1 -maxdepth 2 -exec rm -rf {} + || sudo rm -rf /opt/dashboard/* /opt/dashboard/.[!.]* 2>/dev/null || true
fi
# Copy new dashboard files into place; tolerate empty source during development
sudo cp -r "$DASHBOARD_DIR"/* /opt/dashboard/ 2>/dev/null || true
sudo chown -R dashboard:dashboard /opt/dashboard || true
sudo chown -R dashboard:dashboard /home/dashboard || true

# Remove Python caches so updated code/templates are used immediately
echo -e "${YELLOW}  → Cleaning up Python caches${NC}"
sudo find /opt/dashboard -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
sudo find /opt/dashboard -type f -name '*.pyc' -delete 2>/dev/null || true

# Copy MOTD quotes file for dashboard
echo -e "${YELLOW}  → Copying MOTD quotes for dashboard${NC}"
sudo mkdir -p /opt/dashboard/MOTD
sudo cp "$SCRIPT_DIR/../MOTD/motd-quotes.txt" /opt/dashboard/MOTD/ 2>/dev/null || echo "Quotes file not found, using fallback"

sudo chown -R dashboard:dashboard /opt/dashboard

# Copy images (backgrounds) so dashboard has access to /images/backgrounds
echo -e "${YELLOW}  → Copying images for dashboard backgrounds (if present)${NC}"
if [ -d "$SCRIPT_DIR/../images" ]; then
    sudo rm -rf /opt/dashboard/images
    sudo cp -r "$SCRIPT_DIR/../images" /opt/dashboard/
    sudo chown -R dashboard:dashboard /opt/dashboard/images
else
    echo "No images directory found in repo; skipping background copy"
fi

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

# Prefer the explicit virtualenv python binary when available to avoid PATH issues
if [[ -x "/opt/dashboard/venv/bin/python" ]]; then
    echo "🐍 Starting with virtualenv python"
    exec /opt/dashboard/venv/bin/python /opt/dashboard/server_dashboard.py
else
    echo "🐍 Starting with system python3"
    export PYTHONPATH="/usr/lib/python3/dist-packages:/opt/dashboard:$PYTHONPATH"
    exec python3 /opt/dashboard/server_dashboard.py
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


# Always reload and enable/start the dashboard service to apply updates (idempotent)
echo -e "${YELLOW}  → Enabling and restarting dashboard service${NC}"
sudo systemctl daemon-reload 2>/dev/null || true
# Try enable+start, fall back to start if enable fails (handles transient states)
sudo systemctl enable --now media-dashboard.service 2>/dev/null || sudo systemctl start media-dashboard.service 2>/dev/null || true
sudo systemctl restart media-dashboard.service 2>/dev/null || true

# Wait for service to start and check status
echo -e "${YELLOW}  → Checking service status...${NC}"
sleep 5

if systemctl is-active --quiet media-dashboard; then
    SERVER_IP=$(get_internal_ip)
    # write an install timestamp for debugging/validation
    sudo date --iso-8601=seconds > /opt/dashboard/.last_install 2>/dev/null || true
    # Health check: poll local API so we ensure the new process is responding
    echo -e "${YELLOW}  → Waiting for dashboard API to respond...${NC}"
    ok=false
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if curl -sS --fail http://127.0.0.1:3000/api/status >/dev/null 2>&1; then
            ok=true; break
        fi
        sleep 2
    done
    if [ "$ok" != "true" ]; then
        echo -e "${YELLOW}⚠️ Dashboard started but API did not respond within timeout. Check logs.${NC}"
    fi
    
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