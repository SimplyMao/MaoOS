#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
#  MaoOS Installer
# ─────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
die()  { echo -e "${RED}❌ $1${NC}" >&2; exit 1; }

# Verify we're on Arch
command -v pacman &>/dev/null || die "This script requires an Arch-based distro."

log "🚀 Installing MaoOS..."

# ─── 1. Install yay ───────────────────────────
if ! command -v yay &>/dev/null; then
    log "📦 Installing yay (AUR helper)..."
    local_yay=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$local_yay"
    (cd "$local_yay" && makepkg -si --noconfirm)
    rm -rf "$local_yay"
fi

# ─── 2. Install Packages ──────────────────────
log "📦 Installing packages..."

PACMAN_PKGS=(
    xwayland-satellite
    xdg-desktop-portal-wlr
    wl-clipboard
    foot
    nautilus
    waybar
    wlogout
    wofi
    mako
    awww
    swayidle
    swaylock
    keyd
    neovim
    matugen
)

AUR_PKGS=(
    mangowm-git
    helium-browser-bin
    macos-tahoe-cursor
)

sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# ─── 3. GNOME Dark Mode ───────────────────────
log "🌙 Enabling GNOME dark mode..."
if command -v dconf &>/dev/null; then
    dconf write /org/gnome/desktop/interface/color-scheme '"prefer-dark"'
else
    warn "dconf not found — skipping dark mode setup."
fi

# ─── 4. Apply Configs ─────────────────────────
log "📂 Applying configs..."

MAOOS_DIR=$(mktemp -d)
git clone https://github.com/SimplyMao/MaoOS.git "$MAOOS_DIR"

declare -A CONFIG_DIRS=(
    ["$MAOOS_DIR/mango"]="$HOME/.config/mango"
    ["$MAOOS_DIR/waybar"]="$HOME/.config/waybar"
    ["$MAOOS_DIR/wofi"]="$HOME/.config/wofi"
    ["$MAOOS_DIR/foot"]="$HOME/.config/foot"
    ["$MAOOS_DIR/gtk-3.0"]="$HOME/.config/gtk-3.0"
    ["$MAOOS_DIR/gtk-4.0"]="$HOME/.config/gtk-4.0"
    ["$MAOOS_DIR/matugen"]="$HOME/.config/matugen"
    ["$MAOOS_DIR/qt5ct"]="$HOME/.config/qt5ct"
    ["$MAOOS_DIR/qt6ct"]="$HOME/.config/qt6ct"
    ["$MAOOS_DIR/matuwall"]="$HOME/.config/matuwall"
    ["$MAOOS_DIR/wlogout"]="$HOME/.config/wlogout"
    ["$MAOOS_DIR/fastfetch"]="$HOME/.config/fastfetch"
)

for src in "${!CONFIG_DIRS[@]}"; do
    dest="${CONFIG_DIRS[$src]}"
    if [ -d "$src" ]; then
        mkdir -p "$dest"
        cp -r "$src/." "$dest/"
    else
        warn "Source '$src' not found in repo — skipping."
    fi
done

# keyd config
if [ -f "$MAOOS_DIR/keyd/default.conf" ]; then
    sudo mkdir -p /etc/keyd
    sudo cp "$MAOOS_DIR/keyd/default.conf" /etc/keyd/default.conf
else
    warn "keyd config not found — skipping."
fi

rm -rf "$MAOOS_DIR"

# ─── 5. LazyVim ───────────────────────────────
log "📝 Setting up LazyVim..."
NVIM_CONFIG="$HOME/.config/nvim"
if [ -d "$NVIM_CONFIG" ]; then
    warn "~/.config/nvim already exists — skipping LazyVim install."
else
    git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"
fi

# ─── 6. Enable Services ───────────────────────
log "⚙️  Enabling services..."

if systemctl list-unit-files keyd.service &>/dev/null; then
    sudo systemctl enable --now keyd
else
    warn "keyd service not found — skipping."
fi

# Add .local/bin to PATH in .bashrc if not already there
if ! grep -q ".local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    log "✅ Added ~/.local/bin to PATH in .bashrc"
fi

log "✨ Done! Welcome to MaoOS. Please restart your system."
