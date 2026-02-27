echo "Updating system and installing base-devel, git, and yay..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel

echo "yay is not installed. Installing yay..."
clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si

echo "Installing necessary packages..."
sudo pacman -S --noconfigm waybar pcmanfm foot neovim
yay -S --noconfirm mangowc-git helium-browser-bin

# Optional: Any additional commands like rebooting, restarting services, etc.
echo "All done! Please restart your session or configure your environment as needed."
