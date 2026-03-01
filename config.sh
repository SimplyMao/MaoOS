#!/bin/bash
set -euo pipefail

echo "🚀 Installing MaoOS..."

# 1. Install yay if missing (Helper for both Pacman & AUR)
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
fi

# 2. Combined Package List (Removed xdg-desktop-portal-gtk)
# We use yay for everything now to save lines.
echo "📦 Installing software..."
yay -S --needed --noconfirm \
    niri xwayland-satellite xdg-desktop-portal-gnome \
    waybar nautilus foot neovim keyd rofi \
    matugen qt6-multimedia-ffmpeg helium-browser-bin

# 3. Configs (Using a simpler copy method)
echo "📂 Applying configs..."
[ -d /tmp/maoos ] && rm -rf /tmp/maoos
git clone https://github.com/SimplyMao/MaoOS.git /tmp/maoos

mkdir -p ~/.config/niri ~/.config/waybar
cp -r /tmp/maoos/niri/* ~/.config/niri/
cp -r /tmp/maoos/waybar/* ~/.config/waybar/

sudo mkdir -p /etc/keyd
sudo cp /tmp/maoos/keyd/default.conf /etc/keyd/default.conf

# 4. LazyVim (Keep it simple)
if [ ! -d "$HOME/.config/nvim" ]; then
    git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

# 5. Enable Services & Set Dark Mode
sudo systemctl enable --now keyd
# This ensures the setting exists before niri even starts
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"

echo "✨ Done! Welcome to MaoOS, please restart." 
