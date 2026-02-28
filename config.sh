#!/bin/bash

echo "Updating system and installing base-devel, git, and yay..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel

echo "Installing yay..."
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si --noconfirm
cd ~

echo "Installing necessary packages..."
# FIX 2: Stavfel --noconfigm -> --noconfirm
sudo pacman -S --noconfirm waybar pcmanfm foot neovim wireplumber keyd
yay -S --noconfirm mangowc-git helium-browser-bin

echo "Creating user directories..."
# FIX 3: Ta inte bort mappar med sudo om de ligger i din hemkatalog.
# Och använd 'mkdir -p' så kraschar inte scriptet om de redan finns.
mkdir -p ~/Downloads ~/Documents

# LazyVim setup
echo "Setting up LazyVim..."
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

sudo mkdir -p /etc/keyd
sudo curl -L https://raw.githubusercontent.com/SimplyMao/MaoOS/main/keyd/default.conf -o /etc/keyd/default.conf
# Starta om keyd för att aktivera den nya filen
sudo systemctl enable --now keyd

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
echo "All done! Please restart your session."
