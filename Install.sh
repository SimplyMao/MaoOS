#!/bin/bash
# MaoOS v2: Production CachyOS + Niri Installer (EXT4)
set -euo pipefail

APP_TITLE="MaoOS Installation Assistant"

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

# --- 1. USER SETUP ---
NEW_USER=$(whiptail --title "$APP_TITLE" --inputbox "Enter your desired username:" 10 60 3>&1 1>&2 2>&3)

while true; do
    PASS1=$(whiptail --title "$APP_TITLE" --passwordbox "Enter your password (used for root too):" 10 60 3>&1 1>&2 2>&3)
    PASS2=$(whiptail --title "$APP_TITLE" --passwordbox "Confirm password:" 10 60 3>&1 1>&2 2>&3)
    [[ "$PASS1" == "$PASS2" && -n "$PASS1" ]] && break
    whiptail --title "Error" --msgbox "Passwords do not match. Try again." 10 60
done

# --- 2. DRIVE SELECTION (safe detection) ---
DRIVE_LIST=$(lsblk -dpno NAME,SIZE,TYPE | awk '$3=="disk"{print $1 " (" $2 ")"}')
DRIVE_ARRAY=()
while read -r line; do DRIVE_ARRAY+=("$line" ""); done <<< "$DRIVE_LIST"

SELECTED_DRIVE=$(whiptail --title "$APP_TITLE" --menu \
"Select drive (ALL DATA WILL BE WIPED):" 15 70 6 \
"${DRIVE_ARRAY[@]}" 3>&1 1>&2 2>&3)

FINAL_DRIVE=$(echo "$SELECTED_DRIVE" | awk '{print $1}')

whiptail --title "FINAL WARNING" --yesno \
"Format $FINAL_DRIVE to EXT4?\nThis cannot be undone." 10 60 || exit 1

echo "🧹 Partitioning $FINAL_DRIVE..."

parted -s "$FINAL_DRIVE" mklabel gpt \
    mkpart EFI fat32 1MiB 513MiB set 1 esp on \
    mkpart ROOT ext4 513MiB 100%

[[ "$FINAL_DRIVE" == *"nvme"* ]] && P="p" || P=""
BOOT_PART="${FINAL_DRIVE}${P}1"
ROOT_PART="${FINAL_DRIVE}${P}2"

mkfs.fat -F32 "$BOOT_PART"
mkfs.ext4 -F "$ROOT_PART"

# --- 3. MOUNT & INSTALL BASE ---
echo "📦 Installing CachyOS base system..."

mount "$ROOT_PART" /mnt
mount --mkdir "$BOOT_PART" /mnt/boot/efi

pacstrap /mnt \
    base base-devel \
    linux-cachyos linux-cachyos-headers \
    cachyos-settings cachyos-hooks \
    networkmanager git sudo grub efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab

# Ensure networking inside chroot
cp /etc/resolv.conf /mnt/etc/resolv.conf

# --- 4. SYSTEM CONFIGURATION ---
arch-chroot /mnt /bin/bash <<EOF
set -e

# Time & Locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "maoos" > /etc/hostname

# Enable multilib
sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf

# User Setup
useradd -m -G wheel $NEW_USER
echo "$NEW_USER:$PASS1" | chpasswd
echo "root:$PASS1" | chpasswd

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

# Bootloader (UEFI)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=MaoOS
grub-mkconfig -o /boot/grub/grub.cfg

# Enable services
systemctl enable NetworkManager

# --- User-level software install ---
runuser -u $NEW_USER -- bash <<'USERBLOCK'
set -e

cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm

yay -S --needed --noconfirm \
    niri xwayland-satellite xdg-desktop-portal-gnome \
    waybar nautilus foot neovim keyd rofi-wayland \
    matugen-bin qt6-multimedia-ffmpeg helium-browser-bin swww

git clone https://github.com/SimplyMao/MaoOS.git /tmp/maoos

mkdir -p ~/.config/niri ~/.config/waybar
cp -r /tmp/maoos/niri/* ~/.config/niri/
cp -r /tmp/maoos/waybar/* ~/.config/waybar/

git clone https://github.com/LazyVim/starter ~/.config/nvim
USERBLOCK

systemctl enable keyd

EOF

umount -R /mnt

whiptail --title "✨ Success" --msgbox \
"MaoOS has been successfully installed!\nYou may now reboot." 10 60
