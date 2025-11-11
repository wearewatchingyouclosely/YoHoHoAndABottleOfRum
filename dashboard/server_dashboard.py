# Commit History:
#   2025-10-12 19:14:14 -0400 | mitchell | f034589b | Update commit history in scripts for consistency and tracking
#   2025-10-12 18:57:01 -0400 | mitchell | d0805e20 | 1
#   2025-10-12 18:56:47 -0400 | mitchell | 3e8aa859 | ?
#   2025-10-12 18:56:42 -0400 | mitchell | c9eff979 | Refactor commit header update script for improved functionality and cross-platform compatibility
#   2025-10-12 18:56:19 -0400 | mitchell | eb343aeb | Refactor commit header update script for improved functionality and cross-platform compatibility
#   2025-10-12 18:56:14 -0400 | mitchell | e5a79f0c | Refactor NordVPN status retrieval for improved logic; add script to update commit headers in source files
# ---

#!/usr/bin/env python3
"""
YoHoHoAndABottleOfRum Media Server Dashboard
A web-based dashboard replicating MOTD functionality with responsive design
"""


from flask import Flask, render_template, jsonify, send_from_directory
import subprocess
import re
import requests
import json
import os
from datetime import datetime
import socket
import random

# Resolve the images directory depending on whether running from repo or installed in /opt/dashboard
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
IMAGES_DIR_CANDIDATE_LOCAL = os.path.join(BASE_DIR, 'images')        # /opt/dashboard/images when installed
IMAGES_DIR_CANDIDATE_REPO = os.path.abspath(os.path.join(BASE_DIR, '..', 'images'))  # repo/images during development

# Prefer local images (same folder as dashboard). If absent, fall back to repo-level images.
if os.path.isdir(IMAGES_DIR_CANDIDATE_LOCAL):
    IMAGES_DIR = IMAGES_DIR_CANDIDATE_LOCAL
elif os.path.isdir(IMAGES_DIR_CANDIDATE_REPO):
    IMAGES_DIR = IMAGES_DIR_CANDIDATE_REPO
else:
    # Default to local path (may be created by installer later)
    IMAGES_DIR = IMAGES_DIR_CANDIDATE_LOCAL

app = Flask(__name__, static_url_path='/images', static_folder=IMAGES_DIR)
print(f"[dashboard] IMAGES_DIR resolved to: {IMAGES_DIR}")


# Optional: fallback route for directory listing (for setRandomBackground)
@app.route('/images/backgrounds/')
def list_backgrounds():
    backgrounds_dir = os.path.join(IMAGES_DIR, 'backgrounds')
    if not os.path.isdir(backgrounds_dir):
        return '<html><body>No backgrounds found</body></html>'
    files = [f for f in os.listdir(backgrounds_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.webp'))]
    # Return a simple HTML directory listing
    links = ''.join(f'<a href="{f}">{f}</a><br>' for f in files)
    return f'<html><body>{links}</body></html>'


@app.route('/api/backgrounds')
def api_backgrounds():
    backgrounds_dir = os.path.join(IMAGES_DIR, 'backgrounds')
    if not os.path.isdir(backgrounds_dir):
        print(f"[dashboard] /api/backgrounds: no backgrounds dir at {backgrounds_dir}")
        return jsonify({'backgrounds': []})
    files = [f for f in os.listdir(backgrounds_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.webp'))]
    print(f"[dashboard] /api/backgrounds: found {len(files)} files")
    return jsonify({'backgrounds': files})

class ServerDashboard:
    def __init__(self):
        pass  # Don't cache IP - get it fresh each time
    
    def get_random_quote(self):
        """Get a random quote from the MOTD quotes file (changes on every refresh)"""
        try:
            # Try multiple possible paths for quotes file
            possible_paths = [
                os.path.join(os.path.dirname(os.path.abspath(__file__)), 'MOTD', 'motd-quotes.txt'),  # Local dashboard copy
                '/opt/wawyc/MOTD/motd-quotes.txt',  # Installed location
                os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'MOTD', 'motd-quotes.txt'),  # Dev location
                '/tmp/motd-quotes.txt'  # Fallback location
            ]
            
            quotes_file = None
            for path in possible_paths:
                if os.path.exists(path):
                    quotes_file = path
                    break
            
            if quotes_file and os.path.exists(quotes_file):
                with open(quotes_file, 'r', encoding='utf-8') as f:
                    quotes = [line.strip() for line in f.readlines() if line.strip()]
                
                if quotes:
                    # Random quote on every refresh (no date seeding)
                    return random.choice(quotes)
            
            return "these were not AI generated, ill let it do my programming but i. dont. let. it. do. my. banter."
        except Exception as e:
            return "so easy a stoned loser could do it"
    
    def get_internal_ip(self):
        """Get internal IP address (excluding VPN interfaces) - Enhanced WAWYC Method"""
        # Method 1: Find physical interface IP (avoid VPN tunnels)
        # Look for common physical interfaces and get their IP from private ranges
        for interface in ['eth0', 'ens160', 'ens192', 'ens33', 'enp0s3', 'enp0s8', 'wlan0', 'wlp2s0']:
            try:
                result = subprocess.run(['ip', 'addr', 'show', interface], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    # Enhanced regex to match the bash version exactly
                    ip_match = re.search(r'inet (192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)', result.stdout)
                    if ip_match:
                        return ip_match.group(1)
            except:
                continue
        
        # Method 2: Get private range IPs, but exclude common VPN ranges
        # Exclude nordlynx, tun, tap, ppp interfaces
        try:
            result = subprocess.run(['ip', 'addr', 'show'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                # Find all private IPs
                private_ips = re.findall(r'inet (192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)/', result.stdout)
                for ip in private_ips:
                    if ip[0] != '127.':  # Skip loopback
                        # Get interface name for this IP - simple check to avoid VPN interfaces
                        interface_check = subprocess.run(['ip', 'addr'], capture_output=True, text=True, timeout=3)
                        if interface_check.returncode == 0:
                            # Look for the IP in context and check if it's on a VPN interface
                            ip_context = re.search(rf'^\d+: ([^:]+):.*?inet {re.escape(ip[0])}/', interface_check.stdout, re.MULTILINE | re.DOTALL)
                            if ip_context:
                                interface_name = ip_context.group(1)
                                # Skip known VPN interface patterns
                                if not re.match(r'^(nordlynx|tun|tap|ppp|wg)', interface_name):
                                    return ip[0]
        except:
            pass
        
        # Method 3: Use ip route to find the default route interface and get its IP
        try:
            result = subprocess.run(['ip', 'route', 'get', '8.8.8.8'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                ip_match = re.search(r'src ([\d.]+)', result.stdout)
                if ip_match:
                    return ip_match.group(1)
        except:
            pass
        
        # Method 4: Last resort - try to find any non-loopback IP
        try:
            result = subprocess.run(['hostname', '-I'], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                ip = result.stdout.strip().split()[0]
                return ip if ip else '127.0.0.1'
        except:
            pass
        
        return '127.0.0.1'
    
    def check_service_status(self, url, timeout=3):
        """Check if a service is responding"""
        try:
            response = requests.get(url, timeout=timeout)
            return 'online' if response.status_code == 200 else 'error'
        except:
            return 'offline'
    
    def check_systemd_service(self, service_name):
        """Check systemd service status"""
        try:
            result = subprocess.run(['systemctl', 'is-active', service_name], 
                                  capture_output=True, text=True, timeout=5)
            return result.stdout.strip() == 'active'
        except:
            return False
    
    def get_unpackerr_status(self):
        """Get Unpackerr status - match MOTD logic exactly"""
        try:
            # Check if service is running
            result = subprocess.run(['systemctl', 'is-active', 'unpackerr'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and result.stdout.strip() == 'active':
                return 'running'
            
            # If not running, check if it's enabled/installed
            result = subprocess.run(['systemctl', 'is-enabled', 'unpackerr'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return 'stopped'  # Installed but not running
            else:
                return 'not_installed'  # Not installed
        except:
            return 'not_installed'


    def get_nordvpn_status(self):
        """Get NordVPN connection status (aligned with MOTD logic)"""
        # Check if nordvpn command exists
        try:
            result = subprocess.run(['which', 'nordvpn'], capture_output=True, text=True, timeout=5)
            if result.returncode != 0:
                return {'status': 'not_installed'}
        except Exception:
            return {'status': 'not_installed'}

        try:
            result = subprocess.run(['nordvpn', 'status'], capture_output=True, text=True, timeout=10)
            status_text = result.stdout if result.returncode == 0 else result.stderr
            status_text = status_text.replace('\r', '').replace('\n', '\n').strip()

            # Debug logging
            print(f"[dashboard] NordVPN status output: '{status_text}'")

            # Use same logic as motd_setup.sh
            if 'Status: Connected' in status_text:
                # Extract fields as in motd_setup.sh
                def extract(field):
                    m = re.search(rf'{re.escape(field)}\s*(.+)', status_text)
                    return m.group(1).strip() if m else ''
                country = extract('Country:')
                city = extract('City:')
                technology = extract('Current technology:')
                server = extract('Server:')
                return {
                    'status': 'connected',
                    'country': country,
                    'city': city,
                    'technology': technology,
                    'server': server
                }
            elif 'Status: Disconnected' in status_text:
                return {'status': 'disconnected'}
            elif 'not logged in' in status_text.lower():
                return {'status': 'not_logged_in'}
            else:
                return {'status': 'error', 'message': f'Unknown status: {status_text.strip()}'}
        except Exception as e:
            return {'status': 'error', 'message': str(e)}

    def _extract_nordvpn_field(self, text, field):
        # Helper to extract field value from nordvpn status output
        match = re.search(rf'{re.escape(field)}\s*(.+)', text)
        return match.group(1).strip() if match else 'Unknown'
    
    def get_system_info(self):
        """Get basic system information"""
        try:
            # Get uptime
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.readline().split()[0])
            
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            
            uptime_str = f"{days}d {hours}h {minutes}m"
            
            # Get load average
            with open('/proc/loadavg', 'r') as f:
                load_avg = f.readline().split()[:3]
            
            # Get memory info
            memory_info = {}
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if line.startswith(('MemTotal:', 'MemAvailable:', 'MemFree:')):
                        key, value = line.split()[:2]
                        memory_info[key.rstrip(':')] = int(value)
            
            total_mem = memory_info.get('MemTotal', 0) / 1024 / 1024  # GB
            available_mem = memory_info.get('MemAvailable', 0) / 1024 / 1024  # GB
            used_mem = total_mem - available_mem
            mem_percent = (used_mem / total_mem * 100) if total_mem > 0 else 0
            
            return {
                'uptime': uptime_str,
                'load_avg': load_avg,
                'memory': {
                    'total': f"{total_mem:.1f}",
                    'used': f"{used_mem:.1f}",
                    'available': f"{available_mem:.1f}",
                    'percent': f"{mem_percent:.1f}"
                }
            }
        except:
            return {
                'uptime': 'Unknown',
                'load_avg': ['0.0', '0.0', '0.0'],
                'memory': {'total': '0', 'used': '0', 'available': '0', 'percent': '0'}
            }
    
    def get_disk_usage(self):
        """Get disk usage for main filesystem"""
        try:
            result = subprocess.run(['df', '-h', '/srv/serverFilesystem'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    parts = lines[1].split()
                    return {
                        'total': parts[1],
                        'used': parts[2],
                        'available': parts[3],
                        'percent': parts[4]
                    }
        except:
            pass
        
        return {'total': 'Unknown', 'used': 'Unknown', 'available': 'Unknown', 'percent': '0%'}
    
    def get_dashboard_data(self):
        """Get all dashboard data"""
        server_ip = self.get_internal_ip()  # Get fresh IP each time
        
        # Media services (Unpackerr removed, only in system_services)
        services = {
            'radarr': {
                'name': 'Radarr (Movies)',
                'icon': '🎬',
                'url': f'http://{server_ip}:7878',
                'status': self.check_service_status(f'http://{server_ip}:7878')
            },
            'sonarr': {
                'name': 'Sonarr (TV Shows)', 
                'icon': '📺',
                'url': f'http://{server_ip}:8989',
                'status': self.check_service_status(f'http://{server_ip}:8989')
            },
            'prowlarr': {
                'name': 'Prowlarr (Indexers)',
                'icon': '🔍', 
                'url': f'http://{server_ip}:9696',
                'status': self.check_service_status(f'http://{server_ip}:9696')
            },
            'plex': {
                'name': 'Plex Media Server',
                'icon': '🎭',
                'url': f'http://{server_ip}:32400/web',
                'status': self.check_service_status(f'http://{server_ip}:32400/web')
            },
            'overseerr': {
                'name': 'Overseerr (Requests)',
                'icon': '📋',
                'url': f'http://{server_ip}:5055',
                'status': self.check_service_status(f'http://{server_ip}:5055')
            },
            'qbittorrent': {
                'name': 'qBittorrent',
                'icon': '🌊',
                'url': f'http://{server_ip}:8080',
                'status': self.check_service_status(f'http://{server_ip}:8080')
            },
            'prometheus': {
                'name': 'Prometheus (Monitoring)',
                'icon': '📊',
                'url': f'http://{server_ip}:9090',
                'status': self.check_service_status(f'http://{server_ip}:9090')
            }
        }
        
        # System services - match MOTD logic exactly
        system_services = {
            'unpackerr': {
                'name': 'Unpackerr',
                'description': 'Auto-extracts archives',
                'status': self.get_unpackerr_status()
            },
            'samba': {
                'name': 'Samba File Share',
                'description': f'\\\\\\\\{server_ip}\\\\sambashare',
                'url': f'file:///{server_ip}/sambashare',
                'smb_path': f'\\\\\\\\{server_ip}\\\\sambashare',
                'status': 'running' if self.check_systemd_service('smbd') else 'stopped'
            }
        }
        
        return {
            'server_ip': server_ip,
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'services': services,
            'system_services': system_services,
            'nordvpn': self.get_nordvpn_status(),
            'system_info': self.get_system_info(),
            'disk_usage': self.get_disk_usage(),
            'daily_quote': self.get_random_quote()
        }

# Create dashboard instance
dashboard = ServerDashboard()

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard.html')


@app.route('/miniDashboard')
def mini_dashboard():
    """Lightweight dashboard for small IoT screens (<500px). Uses same API but a trimmed template."""
    # Keep backwards compatibility but redirect to canonical /mini
    from flask import redirect, url_for
    return redirect(url_for('mini'))


@app.route('/mini')
def mini():
    """Canonical mini dashboard route"""
    return render_template('dashboard_mini.html')

@app.route('/api/status')
def api_status():
    """API endpoint for dashboard data"""
    return jsonify(dashboard.get_dashboard_data())

@app.route('/api/refresh')
def api_refresh():
    """Force refresh dashboard data"""
    return jsonify(dashboard.get_dashboard_data())

if __name__ == '__main__':
    print("🚀 Starting YoHoHoAndABottleOfRum Dashboard...")
    server_ip = dashboard.get_internal_ip()
    print(f"📍 Access at: http://{server_ip}:3000")
    print("🔄 Dashboard will auto-refresh every 30 seconds")
    
    # Run Flask app
    app.run(host='0.0.0.0', port=3000, debug=False)