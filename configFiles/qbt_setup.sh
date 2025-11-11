#!/bin/bash

# Get server IP from parameter or fallback to localhost
SERVER_IP="${1:-localhost}"

echo "========================================="
echo "STARTING QBITTORRENT INITIAL SETUP"
echo "========================================="
echo ""
echo "Server IP: $SERVER_IP"
echo "Starting qBittorrent to generate initial configuration..."
echo ""

# Start qBittorrent and capture initial output to get temporary password
qbittorrent-nox > /tmp/qbt_output.log 2>&1 &
QBT_PID=$!

echo "qBittorrent started (PID: $QBT_PID)"
echo "Waiting for configuration generation and temporary password..."

# Monitor the log file for the temporary password
TEMP_PASSWORD=""
for i in {1..30}; do
    if [[ -f /tmp/qbt_output.log ]]; then
        # Check if temporary password line appears in log
        if grep -q "temporary password" /tmp/qbt_output.log; then
            TEMP_PASSWORD=$(grep "temporary password" /tmp/qbt_output.log | grep -oE '[A-Za-z0-9]{8,}' | head -1)
            echo "✓ Temporary password detected: $TEMP_PASSWORD"
            break
        fi
    fi
    echo -n "."
    sleep 1
done

echo ""

# Display the captured output immediately
if [[ -f /tmp/qbt_output.log ]]; then
    echo "📋 qBittorrent startup output:"
    echo "----------------------------------------"
    cat /tmp/qbt_output.log
    echo "----------------------------------------"
    echo ""
fi

if [[ -n "$TEMP_PASSWORD" ]]; then
    echo "========================================="
    echo ""
    echo "🌐 qBittorrent is now running and accessible at: http://$SERVER_IP:8080"
    echo "👤 Username: admin"
    echo "🔐 Password: CHECK ABOVE"
    echo ""
    echo "⚠️  CRITICAL: qBittorrent is STILL RUNNING so you can login now!"
    echo "    1. Open http://$SERVER_IP:8080 in your browser"
    echo "    2. Login with admin / CHECK ABOVE"
    echo "    3. Go to Tools → Options → Web UI"
    echo "    4. Set your permanent password"
    echo "    5. Save settings"
    echo ""
    echo "🎯 When you've successfully set your permanent password,"
    echo -e "   \033[1;32mpress ENTER to stop the temporary qBittorrent session...\033[0m"
else
    echo "⚠️  =========================================================="
    echo "    Please check the output above for password information"
    echo ""
    echo -e "\033[1;33mPress ENTER to stop qBittorrent...\033[0m"
fi

read -r

echo ""
echo "Stopping qBittorrent..."
# Gracefully stop qBittorrent
kill -TERM $QBT_PID 2>/dev/null || true
wait $QBT_PID 2>/dev/null || true

echo "========================================="
echo "QBITTORRENT INITIAL SETUP COMPLETED"
echo "========================================="