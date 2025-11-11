#!/bin/bash
# Debian-compatible Overseerr installer
# Docker-based installation instead of snap

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}📋 Installing Overseerr (Debian Docker method)...${NC}"

# Install Docker if not present
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}  → Installing Docker${NC}"
    sudo apt update
    sudo apt install -y docker.io docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
fi

# Create Overseerr directory
sudo mkdir -p /opt/overseerr
sudo chown $USER:$USER /opt/overseerr

# Create docker-compose file
cat > /opt/overseerr/docker-compose.yml << 'EOF'
version: '3.8'
services:
  overseerr:
    image: sctx/overseerr:latest
    container_name: overseerr
    environment:
      - LOG_LEVEL=info
      - TZ=America/New_York
    ports:
      - 5055:5055
    volumes:
      - /opt/overseerr/config:/app/config
    restart: unless-stopped
EOF

# Start Overseerr
cd /opt/overseerr
docker-compose up -d

echo -e "${GREEN}✅ Overseerr installed successfully${NC}"
echo -e "${YELLOW}📝 Access at: http://$(hostname -I | awk '{print $1}'):5055${NC}"