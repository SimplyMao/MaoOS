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

sudo pacman -Syu --needed --noconfirm niri xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk mako foot nautilus

yay -S --needed --noconfirm dms-shell-bin matugen cava qt6-multimedia-ffmpeg helium-browser-bin

# 3. Enable GNOME Dark Mode
echo "🌙 Enabling GNOME dark mode..."
dconf write /org/gnome/desktop/interface/color-scheme '"prefer-dark"'

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
echo "⚙️ Enabling services..."

systemctl enable --now keyd

systemctl --user enable niri.service
systemctl --user enable dms.service
systemctl --user enable mako.service
systemctl --user enable waybar.service

echo "✨ Done! Welcome to MaoOS, please restart."
