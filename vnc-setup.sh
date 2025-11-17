#!/bin/bash
set -euo pipefail

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

USER_HOME=$(eval echo "~$USER")
VNC_DISPLAY=":1"
VNC_PORT="5901"

echo -e "${BLUE}=== Smart VNC Setup: Ubuntu Desktop Installer ===${NC}"

# ------------------------------
# DE LIST + PACKAGES
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
# DETECT INSTALLED DEs
# ------------------------------
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
# IF NO DE INSTALLED → SHOW INSTALL MENU
# ------------------------------
if [[ ${#installed_des[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No desktop environment detected.${NC}"
    echo
    echo "Choose a desktop environment to install:"
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
        *) echo -e "${RED}Invalid option.${NC}"; exit 1 ;;
    esac

    DE_CMD="${DE_LIST[$DE_NAME]}"

    echo -e "${BLUE}Installing $DE_NAME...${NC}"
    sudo apt update
    sudo apt install -y ${DE_PACKAGES[$DE_CMD]}

    installed_des=("$DE_NAME")
fi

# ------------------------------
# IF DE INSTALLED → MANAGE MENU
# ------------------------------
for de in "${installed_des[@]}"; do
    DE_CMD="${DE_LIST[$de]}"

    echo -e "${BLUE}Detected installed Desktop Environments: ${installed_des[*]}${NC}"
    echo "Managing $de:"
    echo "  1) Reinstall"
    echo "  2) Uninstall (remove binaries)"
    echo "  3) Restart"
    echo "  4) Stop (kill DE)"
    read -rp "Enter choice [1-4, default 3]: " act

    case "$act" in
        1)
            sudo apt purge -y ${DE_PACKAGES[$DE_CMD]} || true
            sudo apt autoremove -y
            sudo apt install -y ${DE_PACKAGES[$DE_CMD]}
            ;;
        2)
            sudo apt purge -y ${DE_PACKAGES[$DE_CMD]} || true
            sudo apt autoremove -y
            for bin in ${DE_PACKAGES[$DE_CMD]}; do
                sudo rm -rf /usr/bin/$bin /usr/share/$bin 2>/dev/null || true
            done
            rm -f "$USER_HOME/.vnc/xstartup" || true
            ;;
        3|"")
            pkill -HUP -f "$DE_CMD" || true
            ;;
        4)
            pkill -f "$DE_CMD" || true
            ;;
    esac
done

# ------------------------------
# INSTALL TIGERVNC IF NOT INSTALLED
# ------------------------------
if ! command -v vncserver &>/dev/null; then
    sudo apt install -y tigervnc-standalone-server tigervnc-tools
fi

# ------------------------------
# VNC PASSWORD
# ------------------------------
echo -e "${BLUE}Set VNC password:${NC}"
vncpasswd

# ------------------------------
# CREATE XSTARTUP
# ------------------------------
if [[ ${#installed_des[@]} -gt 0 ]]; then
    DE_NAME="${installed_des[0]}"
    DE_CMD="${DE_LIST[$DE_NAME]}"

    mkdir -p "$USER_HOME/.vnc"
cat > "$USER_HOME/.vnc/xstartup" <<EOF
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec $DE_CMD
EOF

    chmod +x "$USER_HOME/.vnc/xstartup"
fi

# ------------------------------
# START VNC SERVER
# ------------------------------
vncserver -kill "$VNC_DISPLAY" >/dev/null 2>&1 || true
vncserver "$VNC_DISPLAY" -geometry 1920x1080 -depth 24

echo -e "${GREEN}VNC started on port $VNC_PORT${NC}"

# ------------------------------
# OPTIONAL SYSTEMD AUTOSTART
# ------------------------------
read -rp "Enable VNC autostart on boot? (y/n) [n]: " auto
if [[ "$auto" =~ ^[Yy]$ ]]; then
sudo bash -c "cat >/etc/systemd/system/vncserver@.service <<EOF
[Unit]
Description=VNC Server
After=network.target

[Service]
Type=forking
User=$USER
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable vncserver@1.service
    sudo systemctl start vncserver@1.service
fi

echo -e "${GREEN}=== Setup Complete ===${NC}"
