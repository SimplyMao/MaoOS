#!/bin/bash
set -euo pipefail

echo "🚀 Installing MaoOS..."

# 1. Install Packages
echo "📦 Installing software..."

sudo dnf update -y

# Enable COPR repository for dms and install niri, dms, waybar, wofi, and other dependencies
sudo dnf copr enable -y avengemedia/dms
sudo dnf install -y niri dms xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk mako foot nautilus cava qt6-ffmpeg waybar wofi

# 2. Enable GNOME Dark Mode
echo "🌙 Enabling GNOME dark mode..."
dconf write /org/gnome/desktop/interface/color-scheme '"prefer-dark"'

# 3. Configs
echo "📂 Applying configs..."
[ -d /tmp/maoos ] && rm -rf /tmp/maoos
git clone https://github.com/SimplyMao/MaoOS.git /tmp/maoos

mkdir -p ~/.config/niri ~/.config/waybar ~/.config/wofi
cp -r /tmp/maoos/niri/* ~/.config/niri/
cp -r /tmp/maoos/waybar/* ~/.config/waybar/
cp -r /tmp/maoos/wofi/* ~/.config/wofi/

sudo mkdir -p /etc/keyd
sudo cp /tmp/maoos/keyd/default.conf /etc/keyd/default.conf

# 4. LazyVim
if [ ! -d "$HOME/.config/nvim" ]; then
    git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

# 5. Enable Services
echo "⚙️ Enabling services..."

# Enable and start the keyd service
sudo systemctl enable --now keyd

# Enable user services for niri, dms, and others
systemctl --user enable --now niri.service
systemctl --user enable --now dms.service
systemctl --user enable --now mako.service
systemctl --user enable --now waybar.service

echo "✨ Done! Welcome to MaoOS, please restart."
