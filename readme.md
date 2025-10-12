# YoHoHoAndABottleOfRum Media Server

this repo is pure AI slop. im irredemeable as a developer and im dragging you down with me. enjoy blindly copy pasting commands into the terminal. if you are trying to use multiple drives to expand storage, use LVM (the docs are decent, I see no need to provide any information beyond 'google ubuntu lvm' ).

we're using linux because it's too hard to pirate windows and learning windows server might accidentally cause me to break out in responsibility at my day job. we're using ubuntu because I like saying 'ubuntu'.


## Quick Start Guide

### Step 1: Install Ubuntu Server
1. Download Ubuntu Server 22.04 LTS (or desktop if you're scared and have a nice system to run this on) from [ubuntu.com](https://ubuntu.com/download/server)
2. Create bootable USB drive (usbimager.exe)
3. Install Ubuntu Server on your target machine
4. **Important**: Create a user account during installation (remember username/password)
### Step 2: Connect to Network
**If using WiFi:**
```bash
# Connect to WiFi network (use the neighbors if you can)
sudo nmcli device wifi connect "YOUR_WIFI_NAME" password "YOUR_PASSWORD"

# Verify connection
ip addr show
hostname -I
curl icanhazip.com

# Install OpenSSH so you can SSH in
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh

# Disable UFW once connection is validated 
sudo ufw disable

```

**If using Ethernet:** Should connect automatically, if not, open a ticket with an IT professional of your choice

```bash
# Verify connection
ip addr show
hostname -I
curl icanhazip.com

# Install OpenSSH
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh

# Disable UFW once connection is validated (optional)
sudo ufw disable
echo 'you'll copy paste anything won't you?'
```


### Step 3: Get System Ready
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install git
sudo apt install git -y

# Get your IP address for SSH access later
hostname -I
```

### Step 4: SSH Access (Recommended)
Once network is established, you can use SSH from another computer for easier management:

**Windows:** Use Windows Terminal or download from Microsoft Store  
**Mac/Linux:** Use built-in terminal - instructions below (no seriously, Mac can do this out of the box.)

```bash
ssh username@YOUR_SERVER_IP
```

Replace `username` with your Ubuntu username and `YOUR_SERVER_IP` with the IP from Step 3.

### Step 5: Install This Media Server
```bash
# Clone the repository
git clone https://github.com/wearewatchingyouclosely/YoHoHoAndABottleOfRum

# Navigate to the directory
cd YoHoHoAndABottleOfRum

# Run the installer
sudo bash server_setup.sh
```

## What Gets Installed
- **Plex Media Server** - Stream your media
- **Radarr** - Movie management  
- **Sonarr** - TV show management
- **Prowlarr** - Indexer management
- **qBittorrent** - Download client
- **Overseerr** - Request management
- **Unpackerr** - Automatic archive extraction
- **Prometheus** - System and service monitoring
- **Web Dashboard** - Mobile-friendly web interface
- **Samba** - Network file sharing
- **NordVPN** - Optional VPN client

## Post-Installation
Once this script finishes, your system will be permanently changed. Do not be alarmed. Do not adjust your picture. 

just go ahead and:

```bash
# this is where you go take a break before you do a million little things I didn't show you how to do here. Have fun reading the docs now, I took care of all the command line work. Have fun in the gui.
sudo reboot
```


Access your services at:
- **📱 Web Dashboard:** `http://YOUR_SERVER_IP:3000` *(Mobile-friendly overview)*
- **Plex:** `http://YOUR_SERVER_IP:32400/web`
- **Radarr:** `http://YOUR_SERVER_IP:7878`
- **Sonarr:** `http://YOUR_SERVER_IP:8989`
- **Prometheus:** `http://YOUR_SERVER_IP:9090`
- **And more...**

## Configuration Help
- **TRaSH Guides:** https://trash-guides.info/ (Essential for proper setup of -arr services)
- **Plex Setup:** Configure during first web access
- **NordVPN:** Requires token from your NordVPN account

---
  
═══════════════════════════════════════════════════════════════════
                     M                          
                    dM                          
                    MMr                         
                   4MMML                  .     
                   MMMMM.                xf     
   .              "MMMMM               .MM-     
    Mh..          +MMMMMM            .MMMM      
    .MMM.         .MMMMML.          MMMMMh      
     )MMMh.        MMMMMM         MMMMMMM       
      3MMMMx.     'MMMMMMf      xnMMMMMM"       
      '*MMMMM      MMMMMM.     nMMMMMMP"        
        *MMMMMx    "MMMMM\    .MMMMMMM=         
         *MMMMMh   "MMMMM"   JMMMMMMP           
           MMMMMM   3MMMM.  dMMMMMM            .
            MMMMMM  "MMMM  .MMMMM(        .nnMP"
=..          *MMMMx  MMM"  dMMMM"    .nnMMMMM*  
  "MMn...     'MMMMr 'MM   MMM"   .nMMMMMMM*"   
   "4MMMMnn..   *MMM  MM  MMP"  .dMMMMMMM""     
     ^MMMMMMMMx.  *ML "M .M*  .MMMMMM**"        
        *PMMMMMMhn. *x > M  .MMMM**""           
           ""**MMMMhx/.h/ .=*"                  
                    .3P"%....                   
                  nP"     "*MMnx               
            STONED LOSER INC.
        YoHoHoAndABottleOfRum - WAWYC

═══════════════════════════════════════════════════════════════════

## editors notes
I am not your mother, your sysadmin, or your spouse. I am not a lawyer, accountant, engineer, or any other sort of person who posses professional credentials.  My distribution of this information implies no warranty, responsibility (real or imagined) or other sort of accountability for this content. 

You buy a black and white TV and you turn it on -  you have access to everything that is available to watch. The world switched to color screens, then bigger screens, then flatter screens, and this continued on. But someone, somewhere decided that not enough money was being made. So they figured out how to get us to pay for TV and they called it 'cable' and 'satellite' and put all the good shows on it. But then we had to work so much to pay for all the channels that we started missing the shows when they came on! So they started selling DVDs of the shows, but those were taking up too much space, so they decided to put TV on the Internet! And this was great for while, until some shows started only coming out on the Internet! And now it costs more to watch all the shows on the Internet than the shows on the TV!

it's clearly not a m@n!f3st0 it's just a bash script!!!!!!!