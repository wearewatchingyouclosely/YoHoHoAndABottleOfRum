#!/usr/bin/env python3
"""
YoHoHoAndABottleOfRum Media Server Dashboard
A web-based dashboard replicating MOTD functionality with responsive design
"""

from flask import Flask, render_template, jsonify
import subprocess
import re
import requests
import json
import os
from datetime import datetime
import socket
import random

app = Flask(__name__)

class ServerDashboard:
    def __init__(self):
        pass  # Don't cache IP - get it fresh each time
    
    def get_daily_quote(self):
        """Get a random quote from the MOTD quotes file"""
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
                    # Use date as seed for consistent daily quote
                    today = datetime.now().strftime('%Y-%m-%d')
                    random.seed(today)
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
        """Get NordVPN connection status (match MOTD logic)"""
        # Check if nordvpn command exists
        try:
            result = subprocess.run(['sh', '-c', 'command -v nordvpn >/dev/null 2>&1'],
                                  capture_output=True, text=True, timeout=5)
            if result.returncode != 0:
                return {'status': 'not_installed'}
        except Exception:
            return {'status': 'not_installed'}

        try:
            result = subprocess.run(['nordvpn', 'status'], capture_output=True, text=True, timeout=10)
            status_text = result.stdout if result.returncode == 0 else ''
            if 'Status: Connected' in status_text:
                country = self._extract_nordvpn_field(status_text, 'Country:')
                city = self._extract_nordvpn_field(status_text, 'City:')
                technology = self._extract_nordvpn_field(status_text, 'Current technology:')
                server = self._extract_nordvpn_field(status_text, 'Server:')
                return {
                    'status': 'connected',
                    'country': country,
                    'city': city,
                    'technology': technology,
                    'server': server
                }
            elif 'Status: Disconnected' in status_text:
                return {'status': 'disconnected'}
            else:
                # Anything else is treated as not logged in (MOTD logic)
                return {'status': 'not_logged_in'}
        except Exception:
            return {'status': 'not_installed'}

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
        
        # Media services
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
            },
            'unpackerr_metrics': {
                'name': 'Unpackerr Metrics',
                'icon': '📦',
                'url': f'http://{server_ip}:5656/metrics',
                'status': self.check_service_status(f'http://{server_ip}:5656/metrics')
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
            'daily_quote': self.get_daily_quote()
        }

# Create dashboard instance
dashboard = ServerDashboard()

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard.html')

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