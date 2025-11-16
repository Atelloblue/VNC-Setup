#!/bin/bash
# ================================
# VNC Setup - Ubuntu Desktop Installer
# Interactive VNC + Desktop Environment Setup
# Supports: GNOME, XFCE, LXDE, MATE
# ================================

set -e

USER_HOME=$(eval echo "~$USER")
VNC_DISPLAY=":1"
VNC_PORT="5901"

echo "=== VNC Setup: Ubuntu Desktop Installer ==="

# --- Step 0: Check existing VNC sessions
existing_vnc=$(vncserver -list 2>/dev/null | grep $VNC_DISPLAY || true)
if [[ -n "$existing_vnc" ]]; then
    echo "Existing VNC session detected on $VNC_DISPLAY:"
    echo "$existing_vnc"
    read -rp "Do you want to (s)tart, (k)ill, or (c)ontinue setup? [c]: " vnc_choice
    case "$vnc_choice" in
        s|S)
            vncserver $VNC_DISPLAY
            echo "VNC started on $VNC_DISPLAY"
            exit 0
            ;;
        k|K)
            vncserver -kill $VNC_DISPLAY || true
            echo "Killed existing VNC session."
            ;;
        *)
            echo "Continuing setup..."
            ;;
    esac
fi

# --- Step 1: Update & Upgrade
echo "Updating system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common

# --- Step 2: Choose Desktop Environment
echo "Choose desktop environment to install/use:"
echo "1) GNOME (default Ubuntu desktop)"
echo "2) XFCE (lightweight)"
echo "3) LXDE (very lightweight)"
echo "4) MATE (moderate)"
read -rp "Enter your choice [1-4, default 1]: " de_choice

case "$de_choice" in
    2)
        DE_NAME="XFCE"
        DE_CMD="startxfce4"
        sudo apt install -y xfce4 xfce4-goodies dbus-x11
        ;;
    3)
        DE_NAME="LXDE"
        DE_CMD="startlxde"
        sudo apt install -y lxde dbus-x11
        ;;
    4)
        DE_NAME="MATE"
        DE_CMD="mate-session"
        sudo apt install -y mate-desktop-environment dbus-x11
        ;;
    1|"")
        DE_NAME="GNOME"
        DE_CMD="gnome-session"
        sudo apt install -y ubuntu-desktop gnome-session gdm3 dbus-x11
        ;;
    *)
        echo "Invalid choice, defaulting to GNOME."
        DE_NAME="GNOME"
        DE_CMD="gnome-session"
        sudo apt install -y ubuntu-desktop gnome-session gdm3 dbus-x11
        ;;
esac

echo "Desktop Environment set to $DE_NAME"

# --- Step 3: Install TigerVNC
sudo apt install -y tigervnc-standalone-server tigervnc-tools

# --- Step 4: Set VNC password
echo "Set VNC password for user $USER:"
vncpasswd

# --- Step 5: Configure xstartup
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

# --- Step 6: External access
read -rp "Allow VNC connections from outside the VPS? (y/n) [n]: " ext_access
if [[ "$ext_access" =~ ^[Yy]$ ]]; then
    LOCALHOST_ARG="-localhost no"
else
    LOCALHOST_ARG=""
fi

# --- Step 7: Start VNC server
vncserver $VNC_DISPLAY -geometry 1920x1080 -depth 24 $LOCALHOST_ARG
echo "VNC started on $VNC_DISPLAY (port $VNC_PORT)"

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
echo "Systemd service created and started."
fi

# --- Step 9: Optional apps
read -rp "Install Firefox? (y/n) [y]: " install_firefox
if [[ ! "$install_firefox" =~ ^[Nn]$ ]]; then
    sudo apt install -y firefox
fi

echo "=== VNC Setup Complete ==="
echo "Connect using VNC viewer: <VPS_IP>:$VNC_PORT"
