#!/bin/bash
set -euo pipefail

echo "🚀 Installing MaoOS..."

# 1. Install yay if missing
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
fi

# 2. Install Packages
echo "📦 Installing software..."
yay -S --needed --noconfirm \
    niri xwayland-satellite \
    xdg-desktop-portal xdg-desktop-portal-gtk \
    waybar nautilus foot neovim keyd wofi \
    matugen qt6-multimedia-ffmpeg helium-browser-bin \
    dconf gsettings-desktop-schemas

# 3. Enable GNOME Dark Mode
echo "🌙 Enabling GNOME dark mode..."
gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true

# 4. Configs
echo "📂 Applying configs..."
[ -d /tmp/maoos ] && rm -rf /tmp/maoos
git clone https://github.com/SimplyMao/MaoOS.git /tmp/maoos

mkdir -p ~/.config/niri ~/.config/waybar ~/.config/wofi
cp -r /tmp/maoos/niri/* ~/.config/niri/
cp -r /tmp/maoos/waybar/* ~/.config/waybar/
cp -r /tmp/maoos/wofi/* ~/.config/wofi/

sudo mkdir -p /etc/keyd
sudo cp /tmp/maoos/keyd/default.conf /etc/keyd/default.conf

# 5. LazyVim
if [ ! -d "$HOME/.config/nvim" ]; then
    git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

# 6. Enable Services
sudo systemctl enable --now keyd

echo "✨ Done! Welcome to MaoOS, please restart."
