#!/bin/bash
# MaoOS: Minimal CachyOS + Niri Installer (EXT4 Version)
set -euo pipefail

APP_TITLE="MaoOS Installation Assistant"

# --- 1. TUI: Gather User Info ---
NEW_USER=$(whiptail --title "$APP_TITLE" --inputbox "Enter your desired username:" 10 60 3>&1 1>&2 2>&3)

while true; do
    PASS1=$(whiptail --title "$APP_TITLE" --passwordbox "Enter your user password (also for root):" 10 60 3>&1 1>&2 2>&3)
    PASS2=$(whiptail --title "$APP_TITLE" --passwordbox "Confirm your password:" 10 60 3>&1 1>&2 2>&3)
    [ "$PASS1" = "$PASS2" ] && [ -n "$PASS1" ] && break
    whiptail --title "Error" --msgbox "Passwords do not match. Try again." 10 60
done

# --- 2. TUI: Drive Selection ---
DRIVE_LIST=$(lsblk -dno NAME,SIZE | awk '{print $1 " (" $2 ")"}')
DRIVE_ARRAY=()
while read -r line; do DRIVE_ARRAY+=("$line" ""); done <<< "$DRIVE_LIST"

SELECTED_DRIVE=$(whiptail --title "$APP_TITLE" --menu "Select drive (ALL DATA WILL BE WIPED):" 15 60 5 "${DRIVE_ARRAY[@]}" 3>&1 1>&2 2>&3)
FINAL_DRIVE=$(echo "$SELECTED_DRIVE" | awk '{print $1}')

if ! whiptail --title "FINAL WARNING" --yesno "Format /dev/$FINAL_DRIVE to EXT4? This cannot be undone." 10 60; then
    exit 1
fi

# --- 3. Partitioning & Formatting (EXT4) ---
echo "🧹 Wiping and partitioning /dev/$FINAL_DRIVE..."
sudo parted -s "/dev/$FINAL_DRIVE" mklabel gpt \
    mkpart "EFI" fat32 1MiB 513MiB set 1 esp on \
    mkpart "ROOT" ext4 513MiB 100%

# Handle NVMe naming (p1) vs SATA naming (1)
[[ "$FINAL_DRIVE" == nvme* ]] && P="p" || P=""
BOOT_PART="/dev/${FINAL_DRIVE}${P}1"
ROOT_PART="/dev/${FINAL_DRIVE}${P}2"



sudo mkfs.fat -F 32 "$BOOT_PART"
sudo mkfs.ext4 -F "$ROOT_PART"

# --- 4. Mount & Pacstrap ---
echo "📦 Installing CachyOS Base (No Proton)..."
sudo mount "$ROOT_PART" /mnt
sudo mount --mkdir "$BOOT_PART" /mnt/boot/efi

# Install essentials + GRUB
sudo pacstrap /mnt base linux-cachyos linux-cachyos-headers cachyos-settings cachyos-hooks \
    networkmanager git sudo grub efibootmgr

sudo genfstab -U /mnt >> /mnt/etc/fstab

# --- 5. System Configuration (Chroot) ---
echo "⚙️ Configuring system internals..."
cat <<EOF > /mnt/setup.sh
set -e
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "maoos" > /etc/hostname

# User Setup
useradd -m -G wheel "$NEW_USER"
echo "$NEW_USER:$PASS1" | chpasswd
echo "root:$PASS1" | chpasswd
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# GRUB Installation (UEFI)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=MaoOS
grub-mkconfig -o /boot/grub/grub.cfg

# MaoOS Software Stack
sudo -u "$NEW_USER" bash -c '
    # Build yay (Required for AUR packages)
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -

    # Install UI Packages
    yay -S --needed --noconfirm \
        niri xwayland-satellite xdg-desktop-portal-gnome \
        waybar nautilus foot neovim keyd rofi-wayland \
        matugen-bin qt6-multimedia-ffmpeg helium-browser-bin swww

    # Apply Configs
    git clone https://github.com/SimplyMao/MaoOS.git /tmp/maoos
    mkdir -p ~/.config/niri ~/.config/waybar
    cp -r /tmp/maoos/niri/* ~/.config/niri/
    cp -r /tmp/maoos/waybar/* ~/.config/waybar/
    
    # LazyVim
    git clone https://github.com/LazyVim/starter ~/.config/nvim
'

# Enable Services
systemctl enable NetworkManager
systemctl enable keyd
EOF

sudo arch-chroot /mnt bash setup.sh
rm /mnt/setup.sh

whiptail --title "✨ Success" --msgbox "MaoOS has been installed on EXT4! Reboot now." 10 60
