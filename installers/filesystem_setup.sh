#!/bin/bash
# Filesystem Structure Creation Script
# Based on WAWYC instructions for /srv/serverFilesystem setup

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}📁 Creating Filesystem Structure (WAWYC Method)...${NC}"

# WAWYC Filesystem Structure Implementation
echo -e "${YELLOW}  → Creating /srv/serverFilesystem directory structure${NC}"
mkdir -p /srv/serverFilesystem/media/{movies,tv,music,books,comics,games,software,documents} /srv/serverFilesystem/{downloads,watch}

echo -e "${YELLOW}  → Creating media group (GID 13000)${NC}"
groupadd -g 13000 media 2>/dev/null || echo "Group 'media' already exists"

echo -e "${YELLOW}  → Setting ownership to media group${NC}"
chown -R :media /srv/serverFilesystem

echo -e "${YELLOW}  → Setting permissions (777)${NC}"
chmod -R 777 /srv/serverFilesystem

echo -e "${YELLOW}  → Adding current user to media group${NC}"
# Get the original user (the one who ran sudo)
ORIG_USER="${SUDO_USER:-$USER}"
if [[ -n "$ORIG_USER" && "$ORIG_USER" != "root" ]]; then
    usermod -a -G media "$ORIG_USER"
    echo "Added user '$ORIG_USER' to media group"
else
    echo "Warning: Could not determine original user to add to media group"
fi

echo -e "${YELLOW}  → Setting group ownership and sticky bits${NC}"
chgrp media /srv/serverFilesystem
chmod 2775 /srv/serverFilesystem
chmod g+s,g+w /srv/serverFilesystem

echo -e "${GREEN}✅ Filesystem structure created successfully${NC}"
echo -e "${CYAN}📂 Directory structure:${NC}"
echo -e "   /srv/serverFilesystem/media/{movies,tv,music,books,comics,games,software,documents}"
echo -e "   /srv/serverFilesystem/{downloads,watch}"
echo -e "${CYAN}👥 Media group (GID 13000) configured with proper permissions${NC}"