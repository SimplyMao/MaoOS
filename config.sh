#!/bin/bash
set -euo pipefail

echo "🚀 Installing MaoOS..."

# 1. Install yay if missing (Helper for both Pacman & AUR)
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
fi

# 2. Install Software (Including Adwaita dark dependencies)
echo "📦 Installing software..."
yay -S --needed --noconfirm \
    niri xwayland-satellite xdg-desktop-portal-gnome \
    waybar nautilus foot neovim keyd rofi \
    matugen qt6-multimedia-ffmpeg helium-browser-bin \
    gnome-themes-extra gnome-themes-extra-gtk2 \
    adwaita-qt5-git adwaita-qt6-git

# 3. Force Adwaita Dark System-wide
echo "🌑 Enabling system-wide Adwaita Dark..."

PROFILE_FILE="$HOME/.profile"

# Append only if not already present
grep -qxF 'export GTK_THEME=Adwaita:dark' "$PROFILE_FILE" 2>/dev/null || cat >> "$PROFILE_FILE" <<EOF

# MaoOS Dark Theme
export GTK_THEME=Adwaita:dark
export GTK2_RC_FILES=/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc
export QT_STYLE_OVERRIDE=Adwaita-Dark
EOF

# 4. Configs
echo "📂 Applying configs..."
[ -d /tmp/maoos ] && rm -rf /tmp/maoos
git clone https://github.com/SimplyMao/MaoOS.git /tmp/maoos

mkdir -p ~/.config/niri ~/.config/waybar
cp -r /tmp/maoos/niri/* ~/.config/niri/
cp -r /tmp/maoos/waybar/* ~/.config/waybar/

sudo mkdir -p /etc/keyd
sudo cp /tmp/maoos/keyd/default.conf /etc/keyd/default.conf

# 5. LazyVim
if [ ! -d "$HOME/.config/nvim" ]; then
    git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

# 6. Enable Services
sudo systemctl enable --now keyd

echo "✨ Done! Welcome to MaoOS, please restart."
