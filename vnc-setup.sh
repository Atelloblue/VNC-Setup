#!/bin/bash
# ================================
# Smart VNC Setup - Ubuntu Desktop Installer
# Detects installed DEs, installs only if needed
# Supports: GNOME, XFCE, LXDE, MATE, KDE, Cinnamon, Budgie, Deepin
# ================================

set -euo pipefail

# --- Colors ---
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

USER_HOME=$(eval echo "~$USER")
VNC_DISPLAY=":1"
VNC_PORT="5901"

echo -e "${BLUE}=== Smart VNC Setup: Ubuntu Desktop Installer ===${NC}"

# --- Step 0: Check existing VNC sessions ---
existing_vnc=$(vncserver -list 2>/dev/null | grep "$VNC_DISPLAY" || true)
if [[ -n "$existing_vnc" ]]; then
    echo -e "${YELLOW}Existing VNC session detected on $VNC_DISPLAY:${NC}"
    echo "$existing_vnc"
    echo "Choose an action:"
    echo "  1) Start existing session"
    echo "  2) Kill existing session"
    echo "  3) Continue with setup"
    read -rp "Enter choice [1-3, default 3]: " vnc_choice
    case "$vnc_choice" in
        1)
            vncserver "$VNC_DISPLAY"
            echo -e "${GREEN}VNC started on $VNC_DISPLAY${NC}"
            exit 0
            ;;
        2)
            vncserver -kill "$VNC_DISPLAY" || true
            echo -e "${GREEN}Killed existing VNC session.${NC}"
            ;;
        *)
            echo "Continuing setup..."
            ;;
    esac
fi

# --- Step 1: Update & Upgrade ---
echo -e "${BLUE}Step 1: Updating system...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common
echo -e "${GREEN}System updated.${NC}"
read -rp "Press Enter to continue..."

# --- Step 2: Detect installed DEs ---
echo -e "${BLUE}Step 2: Detecting installed Desktop Environments...${NC}"

declare -A DE_LIST=(
    ["GNOME"]="gnome-session"
    ["XFCE"]="startxfce4"
    ["LXDE"]="startlxde"
    ["MATE"]="mate-session"
    ["KDE"]="startplasma-x11"
    ["Cinnamon"]="cinnamon-session"
    ["Budgie"]="budgie-desktop"
    ["Deepin"]="startdde"
)

declare -A DE_PACKAGES=(
    ["gnome-session"]="ubuntu-desktop gnome-session gdm3 nautilus gedit gnome-terminal"
    ["startxfce4"]="xfce4 xfce4-goodies lightdm thunar mousepad xfce4-terminal xfce4-panel xfce4-session"
    ["startlxde"]="lxde lxde-common lxdm pcmanfm lxterminal"
    ["mate-session"]="mate-desktop-environment lightdm caja mate-terminal pluma"
    ["startplasma-x11"]="kde-plasma-desktop plasma-desktop sddm konsole dolphin kate kwrite kscreen systemsettings"
    ["cinnamon-session"]="cinnamon lightdm nemo gnome-terminal"
    ["budgie-desktop"]="ubuntu-budgie-desktop lightdm budgie-desktop nemo gnome-terminal"
    ["startdde"]="dde lightdm dde-file-manager dde-terminal"
)

# Detect installed DEs
installed_des=()
for de in "${!DE_LIST[@]}"; do
    if command -v "${DE_LIST[$de]}" &>/dev/null; then
        installed_des+=("$de")
    fi
done

if [[ ${#installed_des[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No desktop environment detected.${NC}"
else
    echo -e "${GREEN}Detected installed Desktop Environments: ${installed_des[*]}${NC}"
fi

# --- Step 2a: Manage each detected DE ---
for de in "${installed_des[@]}"; do
    DE_CMD="${DE_LIST[$de]}"
    echo -e "Managing $de:"
    echo "  1) Reinstall"
    echo "  2) Uninstall (remove binaries)"
    echo "  3) Restart"
    echo "  4) Stop (kill all DE processes)"
    read -rp "Enter choice [1-4, default 3]: " de_action
    case "$de_action" in
        1)
            echo "Reinstalling $de completely..."
            sudo apt purge -y ${DE_PACKAGES[$DE_CMD]} || true
            sudo apt autoremove -y
            sudo apt install -y ${DE_PACKAGES[$DE_CMD]}
            ;;
        2)
            echo "Purging $de completely, removing binaries..."
            sudo apt purge -y ${DE_PACKAGES[$DE_CMD]} || true
            sudo apt autoremove -y
            # Remove DE binaries explicitly
            for bin in ${DE_PACKAGES[$DE_CMD]}; do
                sudo rm -rf /usr/bin/$bin /usr/share/$bin 2>/dev/null || true
            done
            if [[ -f "$USER_HOME/.vnc/xstartup" ]]; then
                rm -f "$USER_HOME/.vnc/xstartup"
                echo -e "${GREEN}Removed .vnc/xstartup${NC}"
            fi
            ;;
        3|"")
            echo "Restarting $de..."
            pkill -HUP -f "$DE_CMD" || echo "No running session to restart."
            ;;
        4)
            echo "Stopping $de..."
            pkill -f "$DE_CMD" || echo "No running session to stop."
            ;;
        *)
            echo -e "${RED}Invalid choice, continuing...${NC}"
            ;;
    esac
done

# --- Refresh installed DEs list after management ---
installed_des=()
for de in "${!DE_LIST[@]}"; do
    if command -v "${DE_LIST[$de]}" &>/dev/null; then
        installed_des+=("$de")
    fi
done

echo -e "${GREEN}Desktop Environments installed/managed: ${installed_des[*]:-None}${NC}"
read -rp "Press Enter to continue..."

# --- Step 3: Install TigerVNC if not installed ---
if ! command -v vncserver &>/dev/null; then
    echo -e "${BLUE}Step 3: Installing TigerVNC...${NC}"
    sudo apt install -y tigervnc-standalone-server tigervnc-tools
    echo -e "${GREEN}TigerVNC installed.${NC}"
else
    echo -e "${GREEN}TigerVNC already installed.${NC}"
fi
read -rp "Press Enter to continue..."

# --- Step 4: Set VNC password ---
echo -e "${BLUE}Step 4: Set VNC password for user $USER:${NC}"
vncpasswd || echo "VNC password setup skipped."
read -rp "Press Enter to continue..."

# --- Step 5: Configure xstartup if a DE exists ---
if [[ ${#installed_des[@]} -gt 0 ]]; then
    DE_NAME="${installed_des[0]}"
    DE_CMD="${DE_LIST[$DE_NAME]}"
    echo -e "${BLUE}Step 5: Configuring VNC session for $DE_NAME...${NC}"
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
else
    echo -e "${YELLOW}No DE installed; skipping xstartup configuration.${NC}"
fi
read -rp "Press Enter to continue..."

# --- Step 6: External access ---
read -rp "Allow VNC connections from outside the VPS? (y/n) [n]: " ext_access
if [[ "$ext_access" =~ ^[Yy]$ ]]; then
    LOCALHOST_ARG="-localhost no"
else
    LOCALHOST_ARG=""
fi

# --- Step 7: Start VNC server ---
echo -e "${BLUE}Starting VNC server...${NC}"
vncserver "$VNC_DISPLAY" -geometry 1920x1080 -depth 24 $LOCALHOST_ARG || echo "VNC server may already be running."
echo -e "${GREEN}VNC started on $VNC_DISPLAY (port $VNC_PORT).${NC}"
read -rp "Press Enter to continue..."

# --- Step 8: Systemd auto-start ---
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

echo -e "${BLUE}=== Smart VNC Setup Complete ===${NC}"
echo -e "${GREEN}Connect using VNC viewer: <VPS_IP>:$VNC_PORT${NC}"
