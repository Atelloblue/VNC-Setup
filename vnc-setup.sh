#!/bin/bash
# ================================
# VNC Setup - VNC & Desktop Installer
# Interactive VNC + Desktop Environment Setup
# Supports: GNOME, XFCE, LXDE, MATE, KDE, Cinnamon
# ================================

set -e

# Colors for nicer UI
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

USER_HOME=$(eval echo "~$USER")
VNC_DISPLAY=":1"
VNC_PORT="5901"

echo -e "${BLUE}=== VNC Setup: VNC & Desktop Installer ===${NC}"

# --- Step 1: Update & Upgrade
echo -e "${BLUE}Step 1: Updating system...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common
echo -e "${GREEN}System updated.${NC}"
read -rp "Press Enter to continue..."

# --- Step 2: Choose Desktop Environment
echo -e "${BLUE}Step 2: Choose Desktop Environment:${NC}"
PS3="Select an option: "
options=("GNOME (default Ubuntu desktop)" "XFCE (lightweight)" "LXDE (very lightweight)" "MATE (moderate)" "KDE (plasma desktop)" "Cinnamon (modern desktop)")
select opt in "${options[@]}"; do
    case "$REPLY" in
        1|"")
            DE_NAME="GNOME"
            DE_CMD="gnome-session"
            echo "Installing GNOME..."
            sudo apt install -y ubuntu-desktop gnome-session gdm3 dbus-x11
            break
            ;;
        2)
            DE_NAME="XFCE"
            DE_CMD="startxfce4"
            echo "Installing XFCE..."
            sudo apt install -y xfce4 xfce4-goodies dbus-x11
            break
            ;;
        3)
            DE_NAME="LXDE"
            DE_CMD="startlxde"
            echo "Installing LXDE..."
            sudo apt install -y lxde dbus-x11
            break
            ;;
        4)
            DE_NAME="MATE"
            DE_CMD="mate-session"
            echo "Installing MATE..."
            sudo apt install -y mate-desktop-environment dbus-x11
            break
            ;;
        5)
            DE_NAME="KDE"
            DE_CMD="startplasma-x11"
            echo "Installing KDE Plasma..."
            sudo apt install -y kde-plasma-desktop dbus-x11
            break
            ;;
        6)
            DE_NAME="Cinnamon"
            DE_CMD="cinnamon-session"
            echo "Installing Cinnamon..."
            sudo apt install -y cinnamon dbus-x11
            break
            ;;
        *)
            echo -e "${RED}Invalid choice, please select 1-6.${NC}"
            ;;
    esac
done
echo -e "${GREEN}Desktop Environment set to $DE_NAME.${NC}"
read -rp "Press Enter to continue..."

# --- Step 3: Install TigerVNC
echo -e "${BLUE}Step 3: Installing TigerVNC...${NC}"
sudo apt install -y tigervnc-standalone-server tigervnc-tools
echo -e "${GREEN}TigerVNC installed.${NC}"
read -rp "Press Enter to continue..."

# --- Step 4: Set VNC password
echo -e "${BLUE}Step 4: Set VNC password for user $USER:${NC}"
vncpasswd
read -rp "Press Enter to continue..."

# --- Step 5: Configure xstartup
echo -e "${BLUE}Step 5: Configuring VNC session...${NC}"
mkdir -p "$USER_HOME/.vnc"
cat > "$USER_HOME/.vnc/xstartup" <<EOL
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export XDG_CURRENT_DESKTOP=$DE_NAME

[ -x /usr/bin/$DE_CMD ] && exec dbus-launch --exit-with-session $DE_CMD
EOL
chmod +x "$USER_HOME/.vnc/xstartup"
echo -e "${GREEN}VNC xstartup configured.${NC}"
read -rp "Press Enter to continue..."

# --- Step 6: External access
read -rp "Allow VNC connections from outside the VPS? (y/n) [n]: " ext_access
if [[ "$ext_access" =~ ^[Yy]$ ]]; then
    LOCALHOST_ARG="-localhost no"
else
    LOCALHOST_ARG=""
fi

# --- Step 7: Start VNC server
echo -e "${BLUE}Starting VNC server...${NC}"
vncserver $VNC_DISPLAY -geometry 1920x1080 -depth 24 $LOCALHOST_ARG
echo -e "${GREEN}VNC started on $VNC_DISPLAY (port $VNC_PORT).${NC}"
read -rp "Press Enter to continue..."

# --- Step 8: Optional systemd auto-start
read -rp "Enable VNC to start automatically on boot? (y/n) [n]: " auto_start
if [[ "$auto_start" =~ ^[Yy]$ ]]; then
sudo bash -c "cat > /etc/systemd/system/vncserver@.service <<EOL
[Unit]
Description=Start TigerVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=$USER
PAMName=login
PIDFile=$USER_HOME/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24 $LOCALHOST_ARG
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOL"
sudo systemctl daemon-reload
sudo systemctl enable vncserver@1.service
sudo systemctl start vncserver@1
echo -e "${GREEN}Systemd service created and started.${NC}"
fi

echo -e "${BLUE}=== VNC Setup Complete ===${NC}"
echo -e "${GREEN}Connect using VNC viewer: <VPS_IP>:$VNC_PORT${NC}"
