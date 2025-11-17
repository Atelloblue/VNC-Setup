# :desktop_computer: VNC Setup

[![made-with-bash](https://img.shields.io/badge/-Made%20with%20Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

A simple script to install and manage **VNC** with your choice of desktop environment (GNOME, XFCE, LXDE, MATE, KDE, Cinnamon) on **Ubuntu** or **Debian** computers.

> This script is unofficial and is not affiliated with any Linux desktop project.

---

## Features

- Install **TigerVNC server** automatically if not present.
- Choose your desktop environment: GNOME, XFCE, LXDE, MATE, KDE, Cinnamon.
- Set up VNC password for secure access.
- Configure VNC to start the selected desktop environment automatically.
- Optional: enable VNC to start automatically on boot via systemd.

---

## Supported Operating Systems

| OS      | Version |       |
| ------- | ------- | ----- |
| Ubuntu  | 22.04   | 🟢    |
| Ubuntu  | 24.04   | 🟠    |
| Ubuntu  | 25.04   | 🟠    |
| Debian  | 11      | 🟠    |
| Debian  | 12      | 🟠    |
| Debian  | 13      | 🟠    |
> Each is tested on GNOME.

> 🟠 = Not Tested  
> 🔴 = Not Supported  
> 🟢 = Supported

---

## Installation

Run the following one-liner as **root** or using `sudo`:

```bash
bash <(curl -s https://raw.githubusercontent.com/Atelloblue/VNC-Setup/refs/heads/main/vnc-setup.sh)
