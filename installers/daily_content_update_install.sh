#!/bin/bash
# Daily Content Update Installer
# Sets up automated daily updates for banners, quotes, and background images

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/daily_content_update.sh"
CRON_JOB="0 2 * * * $UPDATE_SCRIPT"  # Run at 2 AM daily
CRON_FILE="/etc/cron.d/dashboard-content-updates"

echo -e "${CYAN}📅 Installing Daily Content Update System...${NC}"
echo -e "${BLUE}🔄 Setting up automated daily updates for banners, quotes, and backgrounds${NC}"

# Ensure update script is executable
echo -e "${YELLOW}  → Making update script executable${NC}"
chmod +x "$UPDATE_SCRIPT" || {
    echo -e "${RED}❌ Failed to make update script executable${NC}"
    exit 1
}

# Create dashboard user cron job
echo -e "${YELLOW}  → Setting up daily cron job (runs at 2 AM)${NC}"

# Remove any existing cron job
sudo crontab -u dashboard -l 2>/dev/null | grep -v "$UPDATE_SCRIPT" | sudo crontab -u dashboard - 2>/dev/null || true

# Add new cron job
(sudo crontab -u dashboard -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -u dashboard - || {
    echo -e "${RED}❌ Failed to set up cron job for dashboard user${NC}"
    exit 1
}

# Alternative: System-wide cron.d file (more reliable)
echo -e "${YELLOW}  → Creating system-wide cron configuration${NC}"
sudo tee "$CRON_FILE" > /dev/null << EOF
# Daily content updates for YoHoHoAndABottleOfRum Dashboard
# Runs at 2 AM daily to pull latest banners, quotes, and background images
0 2 * * * dashboard $UPDATE_SCRIPT
EOF

sudo chmod 644 "$CRON_FILE" || {
    echo -e "${RED}❌ Failed to set permissions on cron file${NC}"
    exit 1
}

# Test the update script (dry run)
echo -e "${YELLOW}  → Testing update script...${NC}"
if sudo -u dashboard "$UPDATE_SCRIPT" --dry-run 2>/dev/null; then
    echo -e "${GREEN}✅ Update script test passed${NC}"
else
    echo -e "${YELLOW}⚠️ Update script test inconclusive (may be normal)${NC}"
fi

# Verify cron job is installed
echo -e "${YELLOW}  → Verifying cron job installation${NC}"
if sudo crontab -u dashboard -l | grep -q "$UPDATE_SCRIPT"; then
    echo -e "${GREEN}✅ User cron job installed${NC}"
else
    echo -e "${YELLOW}⚠️ User cron job not found${NC}"
fi

if [[ -f "$CRON_FILE" ]]; then
    echo -e "${GREEN}✅ System cron file created${NC}"
else
    echo -e "${YELLOW}⚠️ System cron file not created${NC}"
fi

echo ""
echo -e "${GREEN}✅ Daily Content Update System Installed!${NC}"
echo -e "${WHITE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN} 📅 Automated Updates${NC}"
echo -e "${WHITE}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}⏰ Schedule: Every day at 2:00 AM${NC}"
echo -e "${CYAN}📁 Updates: Banners, quotes, and background images${NC}"
echo -e "${CYAN}📊 Logs: /var/log/dashboard-updates.log${NC}"
echo -e "${CYAN}🔧 Manual run: $UPDATE_SCRIPT${NC}"
echo ""
echo -e "${BLUE}✨ Features:${NC}"
echo -e "${WHITE}  • Zero-touch operation - fully automated${NC}"
echo -e "${WHITE}  • Pulls latest content from GitHub repository${NC}"
echo -e "${WHITE}  • Updates both MOTD and dashboard content${NC}"
echo -e "${WHITE}  • Graceful error handling and logging${NC}"
echo -e "${WHITE}  • Preserves dashboard service functionality${NC}"
echo ""
echo -e "${YELLOW}🎯 Your server will now automatically stay up-to-date with the latest content!${NC}"
