#!/bin/bash
# Prometheus Monitoring Installation Script
# Based on official Prometheus installation methods

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

SERVICE_NAME="prometheus"

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

# Check if Prometheus is already installed and running
if systemctl is-active --quiet prometheus 2>/dev/null; then
    SERVER_IP=$(get_internal_ip)
    echo -e "${GREEN}✅ Prometheus is already installed and running${NC}"
    echo -e "${BLUE}ℹ️  Access via http://$SERVER_IP:9090${NC}"
    echo -e "${YELLOW}⚠️  Skipping installation (service already active)${NC}"
    exit 0
elif systemctl list-unit-files prometheus.service >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Prometheus service exists but is not running${NC}"
    echo -e "${BLUE}ℹ️  Attempting to restart...${NC}"
    sudo systemctl restart prometheus
    sleep 3
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        SERVER_IP=$(get_internal_ip)
        echo -e "${GREEN}✅ Prometheus successfully restarted${NC}"
        echo -e "${BLUE}ℹ️  Access via http://$SERVER_IP:9090${NC}"
        exit 0
    else
        echo -e "${RED}❌ Prometheus failed to restart, continuing with reinstallation...${NC}"
    fi
fi

echo -e "${CYAN}📊 Installing Prometheus Monitoring System...${NC}"

# Create prometheus user
echo -e "${YELLOW}  → Creating prometheus user${NC}"
sudo useradd --no-create-home --shell /bin/false prometheus

# Create directories
echo -e "${YELLOW}  → Creating directories${NC}"
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Download and install Prometheus
echo -e "${YELLOW}  → Downloading Prometheus${NC}"
cd /tmp
PROMETHEUS_VERSION="2.45.0"
wget "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

if [[ ! -f "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" ]]; then
    echo -e "${RED}❌ Failed to download Prometheus${NC}"
    exit 1
fi

echo -e "${YELLOW}  → Extracting and installing Prometheus${NC}"
tar xvf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
cd "prometheus-${PROMETHEUS_VERSION}.linux-amd64"

# Copy binaries
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Copy configuration files
sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus/consoles /etc/prometheus/console_libraries

# Create Prometheus configuration
echo -e "${YELLOW}  → Creating Prometheus configuration${NC}"
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
  
  # Media server services monitoring
  - job_name: 'radarr'
    static_configs:
      - targets: ['localhost:7878']
    metrics_path: '/metrics'
    scrape_interval: 30s
  
  - job_name: 'sonarr'
    static_configs:
      - targets: ['localhost:8989']
    metrics_path: '/metrics'
    scrape_interval: 30s
  
  - job_name: 'prowlarr'
    static_configs:
      - targets: ['localhost:9696']
    metrics_path: '/metrics'
    scrape_interval: 30s
  
  # Unpackerr archive extraction monitoring
  - job_name: 'unpackerr'
    static_configs:
      - targets: ['localhost:5656']
    metrics_path: '/metrics'
    scrape_interval: 15s
EOF

sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Create systemd service file
echo -e "${YELLOW}  → Creating systemd service${NC}"
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file /etc/prometheus/prometheus.yml \\
    --storage.tsdb.path /var/lib/prometheus/ \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries \\
    --web.listen-address=0.0.0.0:9090 \\
    --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

# Install Node Exporter for system metrics
echo -e "${YELLOW}  → Installing Node Exporter${NC}"
NODE_EXPORTER_VERSION="1.6.0"
cd /tmp
wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

if [[ -f "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" ]]; then
    tar xvf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
    cd "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"
    
    # Create node_exporter user
    sudo useradd --no-create-home --shell /bin/false node_exporter
    
    # Install node_exporter
    sudo cp node_exporter /usr/local/bin/
    sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
    
    # Create systemd service for node_exporter
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "${GREEN}    ✓ Node Exporter installed${NC}"
else
    echo -e "${YELLOW}    ⚠️ Node Exporter download failed, continuing without it${NC}"
fi

# Enable and start services
echo -e "${YELLOW}  → Enabling and starting services${NC}"
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

if [[ -f /etc/systemd/system/node_exporter.service ]]; then
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
fi

# Wait for services to start and check status
echo -e "${YELLOW}  → Checking service status...${NC}"
sleep 5

if systemctl is-active --quiet prometheus; then
    SERVER_IP=$(get_internal_ip)
    
    echo ""
    echo -e "${GREEN}✅ Prometheus installation completed successfully!${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN} 📊 Prometheus Monitoring System${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}📍 Web Interface: http://$SERVER_IP:9090${NC}"
    echo -e "${CYAN}📈 Node Metrics: http://$SERVER_IP:9100/metrics${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📝 Monitoring Targets:${NC}"
    echo -e "${WHITE}  • Prometheus itself (self-monitoring)${NC}"
    echo -e "${WHITE}  • System metrics via Node Exporter${NC}"
    echo -e "${WHITE}  • Media services (Radarr, Sonarr, Prowlarr)${NC}"
    echo ""
    echo -e "${BLUE}🔍 Useful Queries:${NC}"
    echo -e "${WHITE}  • up - Check service availability${NC}"
    echo -e "${WHITE}  • node_load1 - System load average${NC}"
    echo -e "${WHITE}  • node_memory_MemAvailable_bytes - Available memory${NC}"
    echo -e "${WHITE}  • node_filesystem_free_bytes - Disk space${NC}"
    echo ""
    echo -e "${YELLOW}📚 Access the web interface to explore metrics and create dashboards${NC}"
    
    # Clean up downloads
    rm -rf /tmp/prometheus-* /tmp/node_exporter-*
else
    echo -e "${RED}❌ Prometheus service failed to start properly${NC}"
    echo -e "${YELLOW}  Checking service status...${NC}"
    sudo systemctl status prometheus --no-pager -l
    exit 1
fi