#!/bin/bash
set -e # Avbryt vid fel

echo "Uppdaterar systemet..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel

# 2. Installera yay (Säkrare hantering)
if ! command -v yay &> /dev/null; then
    echo "Installerar yay..."
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd ~
else
    echo "yay är redan installerat, hoppar över..."
fi

# 3. Paket (La till xdg-desktop-portal)
echo "Installerar verktyg och MangoWC..."
sudo pacman -S --needed --noconfirm waybar pcmanfm foot neovim wireplumber keyd rofi xdg-desktop-portal
yay -S --noconfirm mangowc-git helium-browser-bin wl-clip-persist cliphist wl-clipboard brightnessctl xdg-desktop-portal-wlr

# 4-5. Konfiguration
echo "Fixar konfigurationer..."
mkdir -p ~/.config/niri ~/.config/waybar

rm -rf /tmp/maoos
git clone https://github.com/SimplyMao/MaoOS.git /tmp/maoos

sudo mkdir -p /etc/keyd
sudo cp /tmp/maoos/keyd/default.conf /etc/keyd/default.conf

cp -r /tmp/maoos/niri/* ~/.config/niri/ 2>/dev/null || true
cp -r /tmp/maoos/waybar/* ~/.config/waybar/ 2>/dev/null || true

# 6. LazyVim
if [ ! -d "$HOME/.config/nvim" ]; then
    echo "Setting up LazyVim..."
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
fi

# 7. Aktivera tjänster
echo "Startar Keyd..."
sudo systemctl enable --now keyd

echo "MaoOS är redo!"
