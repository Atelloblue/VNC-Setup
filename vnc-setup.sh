#!/bin/bash
# ================================
# VNC Setup 1.1 - VNC & Desktop Installer with Optional DE Flavors
# Supports: GNOME, XFCE, LXDE, MATE, KDE, Cinnamon
# ================================

set -euo pipefail

# --- Colors for UI ---
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
NC="\033[0m"

USER_HOME=$(eval echo "~$USER")
VNC_DISPLAY=":1"
VNC_GEOMETRY="1920x1080"
VNC_DEPTH="24"

echo -e "${BLUE}=== VNC Setup 3.1 ===${NC}"

# --- Step 1: Update & Upgrade System ---
echo -e "${BLUE}Step 1: Updating system...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common
echo -e "${GREEN}System updated.${NC}"

# --- Step 2: Select Desktop Environment ---
echo -e "${BLUE}Step 2: Select Desktop Environment:${NC}"
PS3="Choose your desktop environment (1-6): "
options=("GNOME" "XFCE" "LXDE" "MATE" "KDE" "Cinnamon")
select opt in "${options[@]}"; do
    case "$REPLY" in
        1)
            DE_NAME="GNOME"; DE_CMD="gnome-session"
            read -rp "Install Ubuntu Flavor? (y/n) [n]: " full
            if [[ "$full" =~ ^[Yy]$ ]]; then
                sudo apt install -y ubuntu-desktop gnome-session gdm3 dbus-x11
            else
                sudo apt install -y gnome-session dbus-x11
            fi
            break
            ;;
        2)
            DE_NAME="XFCE"; DE_CMD="startxfce4"
            read -rp "Install Xubuntu Flavor? (y/n) [n]: " full
            if [[ "$full" =~ ^[Yy]$ ]]; then
                sudo apt install -y xubuntu-desktop dbus-x11
            else
                sudo apt install -y xfce4 xfce4-goodies dbus-x11
            fi
            break
            ;;
        3)
            DE_NAME="LXDE"; DE_CMD="startlxde"
            sudo apt install -y lxde dbus-x11
            break
            ;;
        4)
            DE_NAME="MATE"; DE_CMD="mate-session"
            sudo apt install -y mate-desktop-environment dbus-x11
            break
            ;;
        5)
            DE_NAME="KDE"; DE_CMD="startplasma-x11"
            read -rp "Install Kubuntu Flavor? (y/n) [n]: " full
            if [[ "$full" =~ ^[Yy]$ ]]; then
                sudo apt install -y kubuntu-desktop dbus-x11
            else
                sudo apt install -y kde-plasma-desktop dbus-x11
            fi
            break
            ;;
        6)
            DE_NAME="Cinnamon"; DE_CMD="cinnamon-session"
            sudo apt install -y cinnamon dbus-x11
            break
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1-6.${NC}"
            ;;
    esac
done
echo -e "${GREEN}Desktop Environment set to $DE_NAME.${NC}"

# --- Step 3: Install TigerVNC ---
echo -e "${BLUE}Step 3: Installing TigerVNC...${NC}"
sudo apt install -y tigervnc-standalone-server tigervnc-tools
echo -e "${GREEN}TigerVNC installed.${NC}"

# --- Step 4: Set VNC Password ---
echo -e "${BLUE}Step 4: Set VNC password for user $USER:${NC}"
vncpasswd
echo -e "${GREEN}VNC password configured.${NC}"

# --- Step 5: Configure VNC xstartup ---
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
echo -e "${GREEN}VNC session configured.${NC}"

# --- Step 6: Optional systemd auto-start ---
read -rp "Enable VNC auto-start on boot? (y/n) [n]: " auto_start
if [[ "$auto_start" =~ ^[Yy]$ ]]; then
    read -rp "Allow VNC connections from outside the VPS? (y/n) [n]: " ext_access
    LOCALHOST_ARG=""
    [[ "$ext_access" =~ ^[Yy]$ ]] && LOCALHOST_ARG="-localhost no"

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
ExecStart=/usr/bin/vncserver :%i -geometry $VNC_GEOMETRY -depth $VNC_DEPTH $LOCALHOST_ARG
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOL"
    sudo systemctl daemon-reload
    sudo systemctl enable vncserver@1.service
    echo -e "${GREEN}Systemd service created and enabled.${NC}"
fi

echo -e "${BLUE}=== VNC Setup Complete ===${NC}"
echo -e "${GREEN}Start manually: vncserver $VNC_DISPLAY -geometry $VNC_GEOMETRY -depth $VNC_DEPTH${NC}"
