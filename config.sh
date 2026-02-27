echo "Updating system and installing base-devel, git, and yay..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel

echo "yay is not installed. Installing yay..."
clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si

echo "Installing necessary packages..."
sudo pacman -S --noconfigm waybar pcmanfm foot neovim wiremix
yay -S --noconfirm mangowc-git helium-browser-bin

# Optional: Any additional commands like rebooting, restarting services, etc.
echo " 
/$$      /$$                      /$$$$$$   /$$$$$$ 
| $$$    /$$$                     /$$__  $$ /$$__  $$
| $$$$  /$$$$  /$$$$$$   /$$$$$$ | $$  \ $$| $$  \__/
| $$ $$/$$ $$ |____  $$ /$$__  $$| $$  | $$|  $$$$$$ 
| $$  $$$| $$  /$$$$$$$| $$  \ $$| $$  | $$ \____  $$
| $$\  $ | $$ /$$__  $$| $$  | $$| $$  | $$ /$$  \ $$
| $$ \/  | $$|  $$$$$$$|  $$$$$$/|  $$$$$$/|  $$$$$$/
|__/     |__/ \_______/ \______/  \______/  \______/ 
                                                     "
echo "All done! Please restart your session or configure your environment as needed."
