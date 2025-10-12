#!/bin/bash
# Grafana Installation Script with Unpackerr Dashboard
# Installs Grafana and configures it with Prometheus data source and Unpackerr dashboard

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Check if Grafana is already installed and running
if systemctl is-active --quiet grafana-server 2>/dev/null; then
    SERVER_IP=$(get_internal_ip)
    echo -e "${GREEN}✅ Grafana is already installed and running${NC}"
    echo -e "${BLUE}ℹ️  Access via http://$SERVER_IP:3001${NC}"
    echo -e "${YELLOW}⚠️  Default credentials: admin/admin${NC}"
    exit 0
elif systemctl list-unit-files grafana-server.service >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Grafana service exists but is not running${NC}"
    echo -e "${BLUE}ℹ️  Attempting to restart...${NC}"
    sudo systemctl restart grafana-server
    sleep 5
    if systemctl is-active --quiet grafana-server 2>/dev/null; then
        SERVER_IP=$(get_internal_ip)
        echo -e "${GREEN}✅ Grafana successfully restarted${NC}"
        echo -e "${BLUE}ℹ️  Access via http://$SERVER_IP:3001${NC}"
        exit 0
    else
        echo -e "${RED}❌ Grafana failed to restart, continuing with reinstallation...${NC}"
    fi
fi

echo -e "${CYAN}📊 Installing Grafana with Unpackerr Dashboard...${NC}"
echo -e "${BLUE}📈 Setting up advanced metrics visualization${NC}"

# Install prerequisites
echo -e "${YELLOW}  → Installing prerequisites${NC}"
sudo apt update
sudo apt install -y apt-transport-https software-properties-common wget

# Add Grafana GPG key and repository
echo -e "${YELLOW}  → Adding Grafana repository${NC}"
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

# Install Grafana
echo -e "${YELLOW}  → Installing Grafana${NC}"
sudo apt update
sudo apt install -y grafana

# Configure Grafana to use port 3001 (avoid conflicts)
echo -e "${YELLOW}  → Configuring Grafana${NC}"
sudo cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.bak

# Update Grafana configuration
sudo tee /etc/grafana/grafana.ini > /dev/null <<EOF
[DEFAULT]
instance_name = YoHoHoAndABottleOfRum

[server]
protocol = http
http_addr = 0.0.0.0
http_port = 3001
domain = $(get_internal_ip)
root_url = http://$(get_internal_ip):3001/
serve_from_sub_path = false

[security]
admin_user = admin
admin_password = wawyc2025
secret_key = $(openssl rand -base64 32)

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer

[auth.anonymous]
enabled = false

[log]
mode = console file
level = info

[log.console]
level = info

[log.file]
level = info

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

[analytics]
reporting_enabled = false
check_for_updates = false

[grafana_net]
url = https://grafana.net

[server]
enable_gzip = true
EOF

# Create Prometheus data source configuration
echo -e "${YELLOW}  → Configuring Prometheus data source${NC}"
sudo mkdir -p /etc/grafana/provisioning/datasources
sudo tee /etc/grafana/provisioning/datasources/prometheus.yml > /dev/null <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
EOF

# Create dashboard provisioning configuration
echo -e "${YELLOW}  → Setting up dashboard provisioning${NC}"
sudo mkdir -p /etc/grafana/provisioning/dashboards
sudo tee /etc/grafana/provisioning/dashboards/dashboards.yml > /dev/null <<EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards
EOF

# Create dashboards directory and download Unpackerr dashboard
echo -e "${YELLOW}  → Downloading Unpackerr dashboard${NC}"
sudo mkdir -p /etc/grafana/dashboards

# Download the official Unpackerr Grafana dashboard
DASHBOARD_URL="https://grafana.com/api/dashboards/18817/revisions/2/download"
sudo wget -O /etc/grafana/dashboards/unpackerr-dashboard.json "$DASHBOARD_URL" || {
    echo -e "${YELLOW}  → Download failed, creating custom dashboard${NC}"
    # Fallback: Create a basic Unpackerr dashboard
    sudo tee /etc/grafana/dashboards/unpackerr-dashboard.json > /dev/null <<'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Unpackerr Archive Extraction Monitor",
    "tags": ["unpackerr", "media", "archives"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Archive Processing Status",
        "type": "stat",
        "targets": [
          {
            "expr": "unpackerr_extracts_total",
            "legendFormat": "Total Extracts"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "30s"
  }
}
EOF
}

# Set correct ownership for Grafana files
sudo chown -R grafana:grafana /etc/grafana/dashboards
sudo chown -R grafana:grafana /etc/grafana/provisioning

# Enable and start Grafana service
echo -e "${YELLOW}  → Enabling and starting Grafana service${NC}"
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

# Wait for Grafana to start and check status
echo -e "${YELLOW}  → Checking Grafana status...${NC}"
sleep 10

if systemctl is-active --quiet grafana-server; then
    SERVER_IP=$(get_internal_ip)
    
    echo ""
    echo -e "${GREEN}✅ Grafana installation completed successfully!${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN} 📊 Grafana Dashboard${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}🌐 Web Interface: http://$SERVER_IP:3001${NC}"
    echo -e "${CYAN}👤 Username: admin${NC}"
    echo -e "${CYAN}🔑 Password: wawyc2025${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📈 Features:${NC}"
    echo -e "${WHITE}  • Pre-configured Prometheus data source${NC}"
    echo -e "${WHITE}  • Official Unpackerr dashboard (ID: 18817)${NC}"
    echo -e "${WHITE}  • Real-time archive extraction monitoring${NC}"
    echo -e "${WHITE}  • Advanced metrics visualization${NC}"
    echo -e "${WHITE}  • Custom dashboard creation capabilities${NC}"
    echo -e "${WHITE}  • Professional monitoring interface${NC}"
    echo ""
    echo -e "${BLUE}📋 Usage:${NC}"
    echo -e "${WHITE}  • Login with credentials above${NC}"
    echo -e "${WHITE}  • Navigate to Dashboards → Unpackerr${NC}"
    echo -e "${WHITE}  • Monitor archive extraction in real-time${NC}"
    echo -e "${WHITE}  • Create custom dashboards for other services${NC}"
    echo ""
    echo -e "${YELLOW}🎯 Access Grafana at http://$SERVER_IP:3001${NC}"
    echo -e "${YELLOW}📦 Monitor Unpackerr metrics with professional visualizations!${NC}"
else
    echo -e "${RED}❌ Grafana service failed to start properly${NC}"
    echo -e "${YELLOW}  Checking service status...${NC}"
    sudo systemctl status grafana-server --no-pager -l
    
    echo -e "${YELLOW}  Checking service logs...${NC}"
    sudo journalctl -u grafana-server --no-pager -n 20
    exit 1
fi