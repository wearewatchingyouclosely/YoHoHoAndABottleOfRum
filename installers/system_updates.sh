#!/bin/bash
# System Updates Script
# Based on WAWYC instructions: sudo apt-get update -y ; sudo apt-get upgrade -y; sudo ufw disable

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}📦 Running System Updates (WAWYC Method)...${NC}"

# WAWYC System Updates Implementation
echo -e "${YELLOW}  → Running apt-get update -y${NC}"
apt-get update -y

echo -e "${YELLOW}  → Running apt-get upgrade -y${NC}"
apt-get upgrade -y

echo -e "${YELLOW}  → Disabling UFW firewall${NC}"
ufw disable

echo -e "${GREEN}✅ System updates completed successfully${NC}"