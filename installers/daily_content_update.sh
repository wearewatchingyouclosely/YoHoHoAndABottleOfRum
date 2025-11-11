#!/bin/bash
# Daily Content Update Script for YoHoHoAndABottleOfRum
# Automatically pulls latest banners, quotes, and background images from repository

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/wearewatchingyouclosely/YoHoHoAndABottleOfRum.git"
REPO_DIR="/tmp/yoho-daily-update"
LOG_FILE="/var/log/dashboard-updates.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_BASE_DIR="$SCRIPT_DIR/.."

# Ensure log directory exists
sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "❌ ERROR: $1"
    exit 1
}

# Check if running as dashboard user or root
if [[ "$EUID" -eq 0 ]]; then
    # Running as root, switch to dashboard user if it exists
    if id "dashboard" &>/dev/null; then
        log "🔄 Switching to dashboard user for update operations"
        exec sudo -u dashboard "$0" "$@"
    fi
fi

# Check for dry-run flag
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    log "� DRY RUN MODE - No actual changes will be made"
fi

# Clean up any previous temp directory
if [[ -d "$REPO_DIR" ]]; then
    log "🧹 Cleaning up previous temp directory"
    rm -rf "$REPO_DIR" || log "⚠️ Warning: Could not clean up $REPO_DIR"
fi

# Create temp directory
mkdir -p "$REPO_DIR" || error_exit "Could not create temp directory $REPO_DIR"

# Navigate to temp directory
cd "$REPO_DIR" || error_exit "Could not change to $REPO_DIR"

# Clone or pull latest repository
log "📥 Cloning/pulling latest repository content..."
if [[ -d ".git" ]]; then
    git pull --quiet || error_exit "Failed to pull latest changes"
else
    git clone --quiet "$REPO_URL" . || error_exit "Failed to clone repository"
fi

# Update MOTD banners (for MOTD script)
if [[ -d "MOTD/banners" ]]; then
    log "🎨 Updating MOTD banners..."
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo mkdir -p "$REPO_BASE_DIR/MOTD/banners" 2>/dev/null || true
        sudo cp -r MOTD/banners/* "$REPO_BASE_DIR/MOTD/banners/" 2>/dev/null || log "⚠️ No banner files to update"
        sudo chmod 644 "$REPO_BASE_DIR/MOTD/banners/"* 2>/dev/null || true
    fi
    log "✅ Updated $(ls "$REPO_BASE_DIR/MOTD/banners/" 2>/dev/null | wc -l) banner files"
else
    log "⚠️ No MOTD/banners directory found in repository"
fi

# Update MOTD quotes (for MOTD script)
if [[ -f "MOTD/motd-quotes.txt" ]]; then
    log "💬 Updating MOTD quotes..."
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo cp "MOTD/motd-quotes.txt" "$REPO_BASE_DIR/MOTD/" || error_exit "Failed to update quotes file"
        sudo chmod 644 "$REPO_BASE_DIR/MOTD/motd-quotes.txt" || true
    fi
    log "✅ Updated quotes file with $(wc -l < "MOTD/motd-quotes.txt") quotes"
else
    log "⚠️ No MOTD/motd-quotes.txt file found in repository"
fi

# Update dashboard quotes (copy to dashboard location)
if [[ -f "MOTD/motd-quotes.txt" ]]; then
    log "📊 Updating dashboard quotes..."
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo mkdir -p /opt/dashboard/MOTD 2>/dev/null || true
        sudo cp "MOTD/motd-quotes.txt" /opt/dashboard/MOTD/ || log "⚠️ Could not update dashboard quotes"
        sudo chown dashboard:dashboard /opt/dashboard/MOTD/motd-quotes.txt 2>/dev/null || true
    fi
    log "✅ Updated dashboard quotes"
fi

# Update dashboard background images
if [[ -d "images" ]]; then
    log "🖼️ Updating dashboard background images..."
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo mkdir -p /opt/dashboard 2>/dev/null || true
        if [[ -d "/opt/dashboard/images" ]]; then
            sudo rm -rf /opt/dashboard/images
        fi
        sudo cp -r images /opt/dashboard/ || log "⚠️ Could not update dashboard images"
        sudo chown -R dashboard:dashboard /opt/dashboard/images 2>/dev/null || true
    fi
    log "✅ Updated $(find /opt/dashboard/images -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) 2>/dev/null | wc -l) background images"
else
    log "⚠️ No images directory found in repository"
fi

# Clean up temp directory
log "🧹 Cleaning up temporary files..."
cd /tmp || true
rm -rf "$REPO_DIR" || log "⚠️ Warning: Could not clean up $REPO_DIR"

# Verify dashboard service is still running
if systemctl is-active --quiet media-dashboard 2>/dev/null; then
    log "✅ Dashboard service is running"
else
    log "⚠️ Dashboard service not running - attempting restart..."
    sudo systemctl restart media-dashboard 2>/dev/null || log "❌ Could not restart dashboard service"
fi

log "🎉 Daily content update completed successfully!"
echo "" >> "$LOG_FILE"
