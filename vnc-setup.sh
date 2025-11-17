#!/bin/bash
set -euo pipefail

# ------------------------------
# Colors for output
# ------------------------------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# ------------------------------
# Basic variables
# ------------------------------
USER_HOME=$(eval echo "~$USER")
VNC_DISPLAY=":1"
VNC_PORT="5901"

echo -e "${BLUE}=== Smart VNC Setup for Ubuntu ===${NC}"

# ------------------------------
# Desktop Environment definitions
# ------------------------------
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
    ["startxfce4"]="xfce4 xfce4-goodies lightdm thunar mousepad xfce4-terminal"
    ["startlxde"]="lxde lxde-common lxdm pcmanfm lxterminal"
    ["mate-session"]="mate-desktop-environment lightdm caja mate-terminal pluma"
    ["startplasma-x11"]="kde-plasma-desktop plasma-desktop sddm konsole dolphin kate"
    ["cinnamon-session"]="cinnamon lightdm nemo gnome-terminal"
    ["budgie-desktop"]="ubuntu-budgie-desktop lightdm budgie-desktop"
    ["startdde"]="dde lightdm dde-file-manager dde-terminal"
)

# ------------------------------
# Detect installed Desktop Environments
# ------------------------------
echo -e "${BLUE}Checking for installed Desktop Environments...${NC}"
installed_des=()
for de in "${!DE_LIST[@]}"; do
    DE_CMD="${DE_LIST[$de]}"
    for pkg in ${DE_PACKAGES[$DE_CMD]}; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            installed_des+=("$de")
            break
        fi
    done
done

# ------------------------------
# No DE installed → show install menu
# ------------------------------
if [[ ${#installed_des[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No Desktop Environment detected.${NC}"
    echo "Please choose one to install:"
    echo " 1) XFCE"
    echo " 2) GNOME"
    echo " 3) KDE Plasma"
    echo " 4) MATE"
    echo " 5) Cinnamon"
    echo " 6) Budgie"
    echo " 7) Deepin"
    echo " 8) LXDE"
    read -rp "Enter choice [1-8]: " choice

    case "$choice" in
        1) DE_NAME="XFCE" ;;
        2) DE_NAME="GNOME" ;;
        3) DE_NAME="KDE" ;;
        4) DE_NAME="MATE" ;;
        5) DE_NAME="Cinnamon" ;;
        6) DE_NAME="Budgie" ;;
        7) DE_NAME="Deepin" ;;
        8) DE_NAME="LXDE" ;;
        *) echo -e "${RED}Invalid choice. Exiting.${NC}"; exit 1 ;;
    esac

    DE_CMD="${DE_LIST[$DE_NAME]}"

    echo -e "${BLUE}Installing $DE_NAME Desktop Environment...${NC}"
    sudo apt update
    sudo apt install -y ${DE_PACKAGES[$DE_CMD]}
    installed_des=("$DE_NAME")
fi

# ------------------------------
# Manage installed DEs
# ------------------------------
for de in "${installed_des[@]}"; do
    DE_CMD="${DE_LIST[$de]}"
    echo -e "${GREEN}Detected DE: $de${NC}"
    echo "Choose an action for $de:"
    echo " 1) Reinstall"
    echo " 2) Uninstall"
    echo " 3) Restart"
    echo " 4) Stop"
    read -rp "Enter choice [1-4, default 3]: " act

    case "$act" in
        1)
            echo -e "${BLUE}Reinstalling $de...${NC}"
            sudo apt purge -y ${DE_PACKAGES[$DE_CMD]} || true
            sudo apt autoremove -y
            sudo apt install -y ${DE_PACKAGES[$DE_CMD]}
            ;;
        2)
            echo -e "${BLUE}Uninstalling $de...${NC}"
            sudo apt purge -y ${DE_PACKAGES[$DE_CMD]} || true
            sudo apt autoremove -y
            for bin in ${DE_PACKAGES[$DE_CMD]}; do
                sudo rm -rf /usr/bin/$bin /usr/share/$bin 2>/dev/null || true
            done
            rm -f "$USER_HOME/.vnc/xstartup" || true
            ;;
        3|"")
            echo -e "${BLUE}Restarting $de...${NC}"
            pkill -HUP -f "$DE_CMD" || true
            ;;
        4)
            echo -e "${BLUE}Stopping $de...${NC}"
            pkill -f "$DE_CMD" || true
            ;;
    esac
done

# ------------------------------
# Install TigerVNC if missing
# ------------------------------
if ! command -v vncserver &>/dev/null; then
    echo -e "${BLUE}Installing TigerVNC server...${NC}"
    sudo apt install -y tigervnc-standalone-server tigervnc-tools
fi

# ------------------------------
# Set VNC password
# ------------------------------
echo -e "${BLUE}Please set a VNC password:${NC}"
vncpasswd

# ------------------------------
# Configure xstartup
# ------------------------------
DE_NAME="${installed_des[0]}"
DE_CMD="${DE_LIST[$DE_NAME]}"
mkdir -p "$USER_HOME/.vnc"

cat > "$USER_HOME/.vnc/xstartup" <<EOF
#!/bin/bash
# Start the selected Desktop Environment
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec $DE_CMD
EOF

chmod +x "$USER_HOME/.vnc/xstartup"

# ------------------------------
# Start VNC server with optional localhost-only binding
# ------------------------------
echo -e "${BLUE}Starting VNC server...${NC}"
read -rp "Bind VNC to localhost only? (y/n) [y]: " local_only
if [[ "$local_only" =~ ^[Nn]$ ]]; then
    LOCAL_FLAG=""
    echo -e "${YELLOW}VNC will be accessible from all network interfaces.${NC}"
else
    LOCAL_FLAG="-localhost"
    echo -e "${YELLOW}VNC will be bound to localhost only (127.0.0.1).${NC}"
fi

vncserver -kill "$VNC_DISPLAY" >/dev/null 2>&1 || true
vncserver "$VNC_DISPLAY" -geometry 1920x1080 -depth 24 $LOCAL_FLAG

# ------------------------------
# Optional systemd autostart
# ------------------------------
read -rp "Enable VNC autostart on boot? (y/n) [n]: " auto
if [[ "$auto" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Creating systemd service for VNC...${NC}"
    sudo bash -c "cat >/etc/systemd/system/vncserver@.service <<EOF
[Unit]
Description=VNC Server
After=network.target

[Service]
Type=forking
User=$USER
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24 $LOCAL_FLAG
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable vncserver@1.service
    sudo systemctl start vncserver@1.service
fi

echo -e "${GREEN}=== VNC Setup Complete! You can now connect to port $VNC_PORT ===${NC}"
