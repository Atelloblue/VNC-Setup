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

# --- Step 2: Detect or manage Desktop Environment ---
echo -e "${BLUE}Step 2: Checking installed Desktop Environments...${NC}"

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

declare -A DE_CMD_TO_PACKAGE=(
    ["gnome-session"]="ubuntu-desktop gnome-session gdm3 dbus-x11"
    ["startxfce4"]="xfce4 xfce4-goodies dbus-x11"
    ["startlxde"]="lxde dbus-x11"
    ["mate-session"]="mate-desktop-environment dbus-x11"
    ["startplasma-x11"]="kde-plasma-desktop dbus-x11"
    ["cinnamon-session"]="cinnamon dbus-x11"
    ["budgie-desktop"]="ubuntu-budgie-desktop dbus-x11"
    ["startdde"]="dde dbus-x11"
)

installed_de=""
DE_CMD=""

# Detect installed DE
for de in "${!DE_LIST[@]}"; do
    if command -v "${DE_LIST[$de]}" &>/dev/null; then
        installed_de="$de"
        DE_CMD="${DE_LIST[$de]}"
        break
    fi
done

if [[ -n "$installed_de" ]]; then
    echo -e "${YELLOW}Detected installed Desktop Environment: $installed_de${NC}"
    echo "Choose an action:"
    echo "  1) Reinstall"
    echo "  2) Uninstall"
    echo "  3) Restart"
    echo "  4) Stop (kill all DE processes)"
    read -rp "Enter choice [1-4, default 3]: " de_action
    case "$de_action" in
        1)
            echo "Reinstalling $installed_de..."
            sudo apt install --reinstall -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}
            ;;
        2)
            echo "Uninstalling $installed_de..."
            # Remove only installed packages to prevent errors
            for pkg in ${DE_CMD_TO_PACKAGE[$DE_CMD]}; do
                if dpkg -l | grep -qw "$pkg"; then
                    sudo apt purge -y "$pkg"
                fi
            done
            sudo apt autoremove -y
            # Remove VNC xstartup if exists
            if [[ -f "$USER_HOME/.vnc/xstartup" ]]; then
                rm -f "$USER_HOME/.vnc/xstartup"
                echo -e "${GREEN}Removed .vnc/xstartup${NC}"
            fi
            installed_de=""
            ;;
        3|"")
            echo "Restarting $installed_de..."
            pkill -HUP -f "$DE_CMD" || echo "No running session to restart."
            ;;
        4)
            echo "Stopping $installed_de..."
            pkill -f "$DE_CMD" || echo "No running session to stop."
            ;;
        *)
            echo -e "${RED}Invalid choice, continuing...${NC}"
            ;;
    esac
fi

# If no DE is installed (or was uninstalled), prompt for installation
if [[ -z "$installed_de" ]]; then
    echo "No desktop environment installed. Please choose one to install:"
    PS3="Select an option: "
    options=(
        "GNOME (default Ubuntu desktop)"
        "XFCE (lightweight)"
        "LXDE (very lightweight)"
        "MATE (moderate)"
        "KDE Plasma (full-featured)"
        "Cinnamon (user-friendly)"
        "Budgie (sleek lightweight)"
        "Deepin (polished interface)"
    )
    select opt in "${options[@]}"; do
        case "$REPLY" in
            1|"")
                DE_NAME="GNOME"; DE_CMD="gnome-session"
                sudo apt install -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}; break;;
            2)
                DE_NAME="XFCE"; DE_CMD="startxfce4"
                sudo apt install -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}; break;;
            3)
                DE_NAME="LXDE"; DE_CMD="startlxde"
                sudo apt install -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}; break;;
            4)
                DE_NAME="MATE"; DE_CMD="mate-session"
                sudo apt install -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}; break;;
            5)
                DE_NAME="KDE"; DE_CMD="startplasma-x11"
                sudo apt install -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}; break;;
            6)
                DE_NAME="Cinnamon"; DE_CMD="cinnamon-session"
                sudo apt install -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}; break;;
            7)
                DE_NAME="Budgie"; DE_CMD="budgie-desktop"
                sudo apt install -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}; break;;
            8)
                DE_NAME="Deepin"; DE_CMD="startdde"
                sudo apt install -y ${DE_CMD_TO_PACKAGE[$DE_CMD]}; break;;
            *)
                echo -e "${RED}Invalid choice, please select 1-8.${NC}";;
        esac
    done
    installed_de="$DE_NAME"
fi

echo -e "${GREEN}Desktop Environment set to $installed_de.${NC}"
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
vncpasswd
read -rp "Press Enter to continue..."

# --- Step 5: Configure xstartup ---
echo -e "${BLUE}Step 5: Configuring VNC session...${NC}"
mkdir -p "$USER_HOME/.vnc"
cat > "$USER_HOME/.vnc/xstartup" <<EOL
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export XDG_CURRENT_DESKTOP=$installed_de

[ -x /usr/bin/$DE_CMD ] && exec dbus-launch --exit-with-session $DE_CMD
EOL
chmod +x "$USER_HOME/.vnc/xstartup"
echo -e "${GREEN}VNC xstartup configured.${NC}"
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
vncserver "$VNC_DISPLAY" -geometry 1920x1080 -depth 24 $LOCALHOST_ARG
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
