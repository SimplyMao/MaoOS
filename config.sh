#!/bin/bash

# 1. Uppdatera systemet och installera bas-paket
echo "Uppdaterar systemet..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel

# 2. Installera yay (AUR helper)
echo "Installerar yay..."
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si --noconfirm
cd ~

# 3. Installera alla nödvändiga paket
echo "Installerar verktyg och MangoWC..."
sudo pacman -S --noconfirm waybar pcmanfm foot neovim wireplumber keyd rofi
yay -S --noconfirm mangowc-git helium-browser-bin wl-clip-persist cliphist wl-clipboard brightnessctl xdg-desktop-portal-wlr

# 4. Förbered mappar
echo "Skapar mappar..."
mkdir -p ~/.config/mango

# 5. KLONA DITT MAOOS REPO OCH FLYTTA FILER
echo "Hämtar dina dotfiles från MaoOS..."
git clone https://github.com/SimplyMao/MaoOS.git /tmp/maoos

# Flytta Keyd config (behöver sudo för /etc)
sudo mkdir -p /etc/keyd
sudo cp /tmp/maoos/keyd/default.conf /etc/keyd/default.conf

# Flytta MangoWC config
cp -r /tmp/maoos/mango/* ~/.config/mango/
cp -r /tmp/maoos/waybar/* ~/.config/waybar/

# 6. Installera LazyVim
echo "Setting up LazyVim..."
rm -rf ~/.config/nvim # Rensar om det fanns något gammalt
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

# 7. Aktivera Keyd (din Caps Lock -> Super fix)
echo "Startar Keyd..."
sudo systemctl enable keyd
sudo systemctl restart keyd

# 8. Städa upp temporära filer
rm -rf /tmp/maoos
rm -rf /tmp/yay

echo " 
 /$$      /$$                       /$$$$$$  /$$$$$$ 
| $$$    /$$$                      /$$__  $$/$$__  $$
| $$$$  /$$$$  /$$$$$$  /$$$$$$ | $$  \ $$| $$  \__/
| $$ $$/$$ $$ |____  $$ /$$__  $$| $$  | $$|  $$$$$$ 
| $$  $$$| $$  /$$$$$$$| $$  \ $$| $$  | $$ \____  $$
| $$\  $ | $$ /$$__  $$| $$  | $$| $$  | $$ /$$  \ $$
| $$ \/  | $$|  $$$$$$$|  $$$$$$/|  $$$$$$/|  $$$$$$/
|__/     |__/ \_______/ \______/  \______/  \______/ 
                                                     "
echo "Allt är klart! Starta om datorn eller logga ut för att köra MaoOS."
