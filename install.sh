#!/usr/bin/env bash
# =============================================================================
#  MaoOS v3 — Production CachyOS + Niri Installer
#  Supports: UEFI + GPT + EXT4 | Single-disk | CachyOS live ISO
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Colour & logging ────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
die()     { echo -e "${RED}[✗] FATAL:${RESET} $*" >&2; cleanup; exit 1; }

# ─── Constants ───────────────────────────────────────────────────────────────
readonly APP_TITLE="MaoOS Installation Assistant"
readonly MAOOS_REPO="https://github.com/SimplyMao/MaoOS.git"
readonly LAZYVIM_REPO="https://github.com/LazyVim/starter"
readonly SWAPFILE_SIZE_MB=4096
readonly SCRIPT_TMPDIR="$(mktemp -d /tmp/maoos-install.XXXXXX)"

# ─── Cleanup ─────────────────────────────────────────────────────────────────
cleanup() {
    log "Cleaning up temporary files..."
    # Securely wipe the credentials file if it exists
    if [[ -f "$SCRIPT_TMPDIR/credentials" ]]; then
        shred -u "$SCRIPT_TMPDIR/credentials" 2>/dev/null || \
            rm -f "$SCRIPT_TMPDIR/credentials"
    fi
    rm -rf "$SCRIPT_TMPDIR"

    # Attempt unmount only if /mnt appears to be in use
    if mountpoint -q /mnt 2>/dev/null; then
        warn "Attempting emergency unmount of /mnt..."
        umount -R /mnt 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'die "Interrupted by user."' INT TERM

# ─── Preflight checks ────────────────────────────────────────────────────────
preflight() {
    [[ $EUID -eq 0 ]]         || die "Run this script as root."
    [[ -d /sys/firmware/efi ]] || die "UEFI not detected. This installer requires UEFI boot."

    for cmd in parted mkfs.fat mkfs.ext4 pacstrap arch-chroot \
               genfstab whiptail lsblk awk sed git; do
        command -v "$cmd" &>/dev/null || die "Required tool not found: $cmd"
    done

    # Verify CachyOS repos are available
    if ! grep -q '\[cachyos\]' /etc/pacman.conf; then
        die "CachyOS repositories not found in /etc/pacman.conf.\n" \
            "  Boot from the official CachyOS live ISO and try again."
    fi

    success "Preflight checks passed."
}

# ─── Helper: whiptail wrapper with cancel detection ──────────────────────────
wt_inputbox() {
    local title="$1" prompt="$2" default="${3:-}"
    whiptail --title "$title" --inputbox "$prompt" 10 70 "$default" \
        3>&1 1>&2 2>&3 || die "Installation cancelled by user."
}

wt_passwordbox() {
    local title="$1" prompt="$2"
    whiptail --title "$title" --passwordbox "$prompt" 10 70 \
        3>&1 1>&2 2>&3 || die "Installation cancelled by user."
}

wt_menu() {
    local title="$1" prompt="$2"; shift 2
    whiptail --title "$title" --menu "$prompt" 18 78 10 "$@" \
        3>&1 1>&2 2>&3 || die "Installation cancelled by user."
}

wt_yesno() {
    local title="$1" msg="$2"
    whiptail --title "$title" --yesno "$msg" 12 70 3>&1 1>&2 2>&3
}

# ─── 1. User configuration ───────────────────────────────────────────────────
gather_user_config() {
    log "Gathering user configuration..."

    # Username
    while true; do
        NEW_USER=$(wt_inputbox "$APP_TITLE" "Enter your desired username (lowercase, no spaces):")
        if [[ "$NEW_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
            break
        fi
        whiptail --title "Invalid Username" \
            --msgbox "Username must start with a letter/underscore and contain only\nlowercase letters, digits, hyphens, or underscores (max 32 chars)." \
            10 70
    done

    # Hostname
    HOSTNAME=$(wt_inputbox "$APP_TITLE" "Enter hostname for this machine:" "maoos")
    HOSTNAME="${HOSTNAME:-maoos}"

    # Timezone: hardcoded to Stockholm
    TIMEZONE="Europe/Stockholm"

    # Locale
    LOCALE=$(wt_inputbox "$APP_TITLE" \
        "Enter your locale (e.g. en_US.UTF-8):" "en_US.UTF-8")
    LOCALE="${LOCALE:-en_US.UTF-8}"

    # Password (never stored in variables longer than needed)
    while true; do
        PASS1=$(wt_passwordbox "$APP_TITLE" "Enter password (used for $NEW_USER and root):")
        PASS2=$(wt_passwordbox "$APP_TITLE" "Confirm password:")
        if [[ "$PASS1" == "$PASS2" && -n "$PASS1" ]]; then
            break
        else
            whiptail --title "Mismatch" \
                --msgbox "Passwords do not match. Please try again." 8 60
        fi
    done

    # Write credentials to a temp file with restricted permissions
    # so they never persist in shell variables through the chroot
    install -m 600 /dev/null "$SCRIPT_TMPDIR/credentials"
    printf '%s\n%s\n' "$NEW_USER" "$PASS1" > "$SCRIPT_TMPDIR/credentials"
    unset PASS1 PASS2

    success "User configuration collected."
}

# ─── 2. Drive selection & partitioning ───────────────────────────────────────
partition_drive() {
    log "Detecting block devices..."

    mapfile -t RAW_DISKS < <(
        lsblk -dpno NAME,SIZE,TYPE,TRAN | awk '$3=="disk"{print $1 " (" $2 " " $4 ")"}'
    )

    [[ ${#RAW_DISKS[@]} -gt 0 ]] || die "No block devices detected."

    DISK_ARRAY=()
    for d in "${RAW_DISKS[@]}"; do DISK_ARRAY+=("$d" ""); done

    SELECTED=$(wt_menu "$APP_TITLE" \
        "Select installation drive — ALL DATA WILL BE ERASED:" \
        "${DISK_ARRAY[@]}")

    FINAL_DRIVE=$(awk '{print $1}' <<< "$SELECTED")

    # Show disk info before confirmation
    DISK_INFO=$(lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$FINAL_DRIVE" 2>/dev/null || true)
    wt_yesno "⚠ FINAL WARNING" \
"You are about to PERMANENTLY ERASE:
  ${FINAL_DRIVE}

Current contents:
${DISK_INFO}

This CANNOT be undone. Are you absolutely sure?" || die "Installation cancelled."

    log "Partitioning ${FINAL_DRIVE}..."

    # Wipe any existing partition table / filesystem signatures
    wipefs -af "$FINAL_DRIVE"
    sgdisk --zap-all "$FINAL_DRIVE"

    parted -s "$FINAL_DRIVE" \
        mklabel gpt \
        mkpart EFI  fat32  1MiB   513MiB \
        mkpart ROOT ext4   513MiB 100%   \
        set 1 esp on

    # Settle device nodes
    partprobe "$FINAL_DRIVE"
    sleep 1

    # Partition naming: /dev/sda1 vs /dev/nvme0n1p1
    if [[ "$FINAL_DRIVE" =~ nvme|mmcblk ]]; then
        BOOT_PART="${FINAL_DRIVE}p1"
        ROOT_PART="${FINAL_DRIVE}p2"
    else
        BOOT_PART="${FINAL_DRIVE}1"
        ROOT_PART="${FINAL_DRIVE}2"
    fi

    log "Formatting partitions..."
    mkfs.fat -F32 -n EFI    "$BOOT_PART"
    mkfs.ext4 -F  -L MaoOS  "$ROOT_PART"

    success "Drive partitioned: ${BOOT_PART} (EFI) | ${ROOT_PART} (ROOT)"
}

# ─── 3. Mount & install base system ──────────────────────────────────────────
install_base() {
    log "Mounting filesystems..."
    mount "$ROOT_PART" /mnt
    mount --mkdir "$BOOT_PART" /mnt/boot/efi

    # Swapfile
    log "Creating ${SWAPFILE_SIZE_MB}MiB swapfile..."
    dd if=/dev/zero of=/mnt/swapfile bs=1M count="$SWAPFILE_SIZE_MB" status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile

    log "Installing CachyOS base system (this will take a few minutes)..."
    pacstrap -K /mnt \
        base base-devel \
        linux-cachyos linux-cachyos-headers \
        cachyos-settings cachyos-hooks \
        networkmanager iwd \
        git curl wget rsync \
        sudo grub efibootmgr \
        man-db man-pages texinfo \
        bash bash-completion \
        reflector \
        intel-ucode amd-ucode

    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    # Append swapfile entry
    echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab

    # Bind-mount resolv.conf so DNS works inside chroot
    mount --bind /etc/resolv.conf /mnt/etc/resolv.conf

    success "Base system installed."
}

# ─── 4. System configuration inside chroot ───────────────────────────────────
configure_system() {
    log "Configuring system inside chroot..."

    # Read credentials from temp file — never pass raw passwords as arguments
    local cred_src="$SCRIPT_TMPDIR/credentials"
    cp "$cred_src" /mnt/tmp/.maoos_creds
    chmod 600 /mnt/tmp/.maoos_creds

    arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT
# ── Time & locale ─────────────────────────────────────────────────────────────
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "LC_ALL=${LOCALE}" >> /etc/locale.conf

# ── Swedish keyboard layout ───────────────────────────────────────────────────
# TTY / console keymap
echo "KEYMAP=sv-latin1" > /etc/vconsole.conf

# X11 / Wayland keymap (used by Niri and most Wayland compositors)
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<'KBCONF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout"  "se"
    Option "XkbModel"   "pc105"
    Option "XkbVariant" ""
EndSection
KBCONF

# ── Hostname & hosts ──────────────────────────────────────────────────────────
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# ── Pacman tweaks ─────────────────────────────────────────────────────────────
# Enable multilib
sed -i '/^\[multilib\]/{n;s/^#//}' /etc/pacman.conf
sed -i 's/^#\(\[multilib\]\)/\1/' /etc/pacman.conf

# Parallel downloads + colour
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf

# ── User & root accounts ──────────────────────────────────────────────────────
NEW_USER=\$(sed -n '1p' /tmp/.maoos_creds)
PASS=\$(sed -n '2p' /tmp/.maoos_creds)

useradd -m -G wheel,audio,video,storage,optical,network -s /bin/bash "\$NEW_USER"
printf '%s:%s\n' "\$NEW_USER" "\$PASS" | chpasswd
printf '%s:%s\n' "root" "\$PASS" | chpasswd
unset PASS

shred -u /tmp/.maoos_creds

# Sudo: wheel group, require password
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel

# ── mkinitcpio ────────────────────────────────────────────────────────────────
mkinitcpio -P

# ── GRUB bootloader ───────────────────────────────────────────────────────────
grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=MaoOS \
    --removable

# Improve GRUB defaults
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/' /etc/default/grub
sed -i 's/^#GRUB_DISABLE_SUBMENU/GRUB_DISABLE_SUBMENU/' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# ── Enable core services ──────────────────────────────────────────────────────
systemctl enable NetworkManager
systemctl enable reflector.timer
systemctl enable fstrim.timer   # SSD health

# ── AUR helper & desktop environment (runs as user) ──────────────────────────
NEW_USER=\$(sed -n '1p' /tmp/.maoos_creds 2>/dev/null || cat /tmp/.maoos_creds_name)

runuser -u "\$NEW_USER" -- bash -l <<'USERSCRIPT'
set -euo pipefail

export HOME="/home/\$(whoami)"
export XDG_CONFIG_HOME="\$HOME/.config"
export XDG_DATA_HOME="\$HOME/.local/share"
export XDG_CACHE_HOME="\$HOME/.cache"

cd /tmp

# ── yay AUR helper ────────────────────────────────────────────────────────────
echo ">>> Installing yay AUR helper..."
git clone --depth=1 https://aur.archlinux.org/yay.git /tmp/yay-build
cd /tmp/yay-build
makepkg -si --noconfirm --noprogressbar
cd /tmp
rm -rf /tmp/yay-build

# ── Niri desktop stack ───────────────────────────────────────────────────────
echo ">>> Installing Niri desktop stack..."
yay -S --needed --noconfirm --noprogressbar \
    niri \
    xwayland-satellite \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-wlr \
    waybar \
    nautilus \
    foot \
    neovim \
    keyd \
    rofi-wayland \
    matugen-bin \
    qt6-multimedia-ffmpeg \
    helium-browser-bin \
    swww \
    wl-clipboard \
    grim slurp \
    mako \
    polkit-gnome \
    playerctl \
    pavucontrol \
    nwg-look \
    ttf-jetbrains-mono-nerd \
    ttf-nerd-fonts-symbols \
    papirus-icon-theme

# ── MaoOS dotfiles ────────────────────────────────────────────────────────────
echo ">>> Cloning MaoOS configuration..."
git clone --depth=1 "${MAOOS_REPO}" "\$HOME/.maoos-dotfiles"

# Only copy configs that exist in the repo
for dir in niri waybar foot mako rofi; do
    if [[ -d "\$HOME/.maoos-dotfiles/\$dir" ]]; then
        mkdir -p "\$XDG_CONFIG_HOME/\$dir"
        cp -r "\$HOME/.maoos-dotfiles/\$dir/." "\$XDG_CONFIG_HOME/\$dir/"
        echo "  Installed \$dir config"
    fi
done

# ── LazyVim ───────────────────────────────────────────────────────────────────
echo ">>> Installing LazyVim..."
[[ -d "\$XDG_CONFIG_HOME/nvim" ]] && mv "\$XDG_CONFIG_HOME/nvim" "\$XDG_CONFIG_HOME/nvim.bak"
git clone --depth=1 "${LAZYVIM_REPO}" "\$XDG_CONFIG_HOME/nvim"
# Remove the LazyVim git history so user can track their own changes
rm -rf "\$XDG_CONFIG_HOME/nvim/.git"

# ── Niri autostart ────────────────────────────────────────────────────────────
mkdir -p "\$HOME/.local/bin"
cat > "\$HOME/.local/bin/start-niri" <<'EOF'
#!/usr/bin/env bash
# Environment for Niri session
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=niri
export XDG_CURRENT_DESKTOP=niri
export MOZ_ENABLE_WAYLAND=1
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
exec niri-session
EOF
chmod +x "\$HOME/.local/bin/start-niri"

echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "\$HOME/.bashrc"

echo ">>> User setup complete."
USERSCRIPT

# ── keyd keyboard daemon ──────────────────────────────────────────────────────
# Create a sane default config (passthrough — user can customise later)
mkdir -p /etc/keyd
cat > /etc/keyd/default.conf <<'KEYDCONF'
[ids]
*

[main]
# Default: capslock acts as escape, hold for ctrl
capslock = overload(ctrl, esc)
KEYDCONF

systemctl enable keyd

CHROOT

    success "System configuration complete."
}

# ─── 5. Final cleanup & summary ──────────────────────────────────────────────
finalise() {
    log "Unmounting filesystems..."
    swapoff /mnt/swapfile 2>/dev/null || true
    umount -R /mnt

    NEW_USER=$(sed -n '1p' "$SCRIPT_TMPDIR/credentials" 2>/dev/null || echo "your user")

    whiptail --title "✨ MaoOS Installation Complete" --msgbox \
"Installation finished successfully!

  User:      ${NEW_USER}
  Hostname:  ${HOSTNAME}
  Timezone:  ${TIMEZONE}
  Bootloader: GRUB (EFI)

Next steps:
  1. Remove the installation media
  2. Reboot: systemctl reboot
  3. Login and run 'start-niri' to launch your desktop

Enjoy MaoOS!" 20 70
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat <<'BANNER'
  __  __             ___  ____
 |  \/  | __ _  ___ / _ \/ ___|
 | |\/| |/ _` |/ _ \ | | \___ \
 | |  | | (_| | |_|| |_| |__) |
 |_|  |_|\__,_|\___/\___/|____/  v3
 Production CachyOS + Niri Installer
BANNER
    echo -e "${RESET}"
    sleep 1

    preflight
    gather_user_config
    partition_drive
    install_base
    configure_system
    finalise
}

main "$@"
