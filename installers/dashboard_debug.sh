#!/bin/bash
# Dashboard Debug Script
# Checks common issues with dashboard installation

echo "🔍 Dashboard Installation Debug"
echo "═══════════════════════════════════"

echo "📁 Checking file paths..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR/../dashboard"

echo "Script directory: $SCRIPT_DIR"
echo "Dashboard directory: $DASHBOARD_DIR"
echo "Dashboard exists: $(test -d "$DASHBOARD_DIR" && echo "✅ YES" || echo "❌ NO")"

if [[ -d "$DASHBOARD_DIR" ]]; then
    echo "📄 Dashboard files:"
    ls -la "$DASHBOARD_DIR"
    echo ""
    echo "📄 Template files:"
    ls -la "$DASHBOARD_DIR/templates/" 2>/dev/null || echo "❌ Templates directory not found"
fi

echo ""
echo "🐍 Python environment check..."
python3 --version
pip3 --version 2>/dev/null || echo "❌ pip3 not found"

echo ""
echo "📦 Service status..."
systemctl list-unit-files media-dashboard.service 2>/dev/null && echo "✅ Service file exists" || echo "❌ Service file not found"
systemctl is-active media-dashboard 2>/dev/null && echo "✅ Service is active" || echo "❌ Service is not active"
systemctl is-enabled media-dashboard 2>/dev/null && echo "✅ Service is enabled" || echo "❌ Service is not enabled"

echo ""
echo "📋 Service logs (last 10 lines):"
journalctl -u media-dashboard --no-pager -n 10 2>/dev/null || echo "❌ No logs found"

echo ""
echo "🌐 Port check..."
netstat -tlnp 2>/dev/null | grep :3000 || ss -tlnp 2>/dev/null | grep :3000 || echo "❌ Port 3000 not in use"

echo ""
echo "📁 Installation directory check..."
test -d "/opt/dashboard" && echo "✅ /opt/dashboard exists" || echo "❌ /opt/dashboard not found"
test -f "/opt/dashboard/server_dashboard.py" && echo "✅ Python script exists" || echo "❌ Python script not found"
test -d "/opt/dashboard/venv" && echo "✅ Virtual environment exists" || echo "❌ Virtual environment not found"