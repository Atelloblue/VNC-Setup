# :desktop_computer: VNC Setup

[![made-with-bash](https://img.shields.io/badge/-Made%20with%20Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

A simple script to install and manage VNC with your choice of desktop environment (GNOME, XFCE, MATE, LXDE) on Ubuntu or Debian VPS.

> This script is unofficial and is not affiliated with any Linux desktop project.

---

## Features

- Choose your desktop environment: GNOME, XFCE, MATE, LXDE.
- Detects existing VNC servers and lets you start, stop, or remove them.
- Installs TigerVNC server automatically.
- Sets up VNC password for access.
- Configures VNC to start the selected desktop environment automatically.
- Optional: configure VNC to start automatically on boot with systemd.

---

## Supported Operating Systems

| OS      | Version | Supported |
| ------- | ------- | --------- |
| Ubuntu  | 22.04   | 🟠        |
| Ubuntu  | 24.04   | 🟢        |
| Debian  | 10      | 🟠        |
| Debian  | 11      | 🟠        |
| Debian  | 12      | 🟠        |

> 🟠 = Not Tested  
> 🔴 = Not Supported  
> 🟢 = Supported

---

## Installation

Run the following one-liner on a fresh VPS as **root** or using `sudo`:

```bash
bash <(curl -s https://raw.githubusercontent.com/Atelloblue/VNC-Setup/refs/heads/main/vnc-setup.sh)
