#!/bin/bash

# Flatpak Applications Installation Script
# This script automates the installation of essential Flatpak applications
# Requires Flatpak and Flathub repository to be already configured

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the actual username (works with or without sudo)
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER=$SUDO_USER
else
    ACTUAL_USER=$USER
fi

print_status "Starting Flatpak applications installation script..."
print_status "Installing applications for user: $ACTUAL_USER"

# Check if Flatpak is installed
if ! command -v flatpak &> /dev/null; then
    print_error "Flatpak is not installed. Please install Flatpak first."
    exit 1
fi

# Check if Flathub repository is configured
if ! flatpak remotes | grep -q flathub; then
    print_error "Flathub repository is not configured. Please add Flathub repository first."
    print_status "You can add it with: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
    exit 1
fi

print_success "Flatpak and Flathub repository are available"

# Function to install a Flatpak application
install_flatpak() {
    local app_name=$1
    local app_id=$2

    print_status "Installing $app_name ($app_id)..."

    if sudo -u "$ACTUAL_USER" flatpak install -y flathub "$app_id"; then
        print_success "$app_name installed successfully"
        return 0
    else
        print_error "Failed to install $app_name"
        return 1
    fi
}

# Counter for tracking installations
total_apps=0
successful_apps=0
failed_apps=()

# Define applications to install (App Name, Flatpak ID)
declare -a apps=(
    "Audacity|org.audacityteam.Audacity"
    "Audiveris|org.audiveris.audiveris"
    "VSCodium|com.vscodium.codium"
    "ES-DE|org.es_de.frontend"
    "RetroArch|org.libretro.RetroArch"
    "Steam|com.valvesoftware.Steam"
    "GIMP|org.gimp.GIMP"
    "Gwenview|org.kde.gwenview"
    "Inkscape|org.inkscape.Inkscape"
    "Krita|org.kde.krita"
    "MuseScore|org.musescore.MuseScore"
    "Okular|org.kde.okular"
    "Scribus|net.scribus.Scribus"
    "Upscayl|org.upscayl.Upscayl"
    "Discord|com.discordapp.Discord"
    "FileZilla|org.filezillaproject.Filezilla"
    "Firefox|org.mozilla.firefox"
    "Google Chrome|com.google.Chrome"
    "RustDesk|com.rustdesk.RustDesk"
    "Thunderbird|org.mozilla.Thunderbird"
    "Transmission|com.transmissionbt.Transmission"
    "Zoom|us.zoom.Zoom"
    "Slack|com.slack.Slack"
    "HandBrake|fr.handbrake.ghb"
    "Kdenlive|org.kde.kdenlive"
    "Kodi|tv.kodi.Kodi"
    "Podcasts|org.gnome.Podcasts"
    "Strawberry|org.strawberrymusicplayer.strawberry"
    "VLC Media Player|org.videolan.VLC"
    "OnlyOffice|org.onlyoffice.desktopeditors"
    "Bitwarden|com.bitwarden.desktop"
    "KDE Calculator|org.kde.kalk"
    "Flatseal|com.github.tchx84.Flatseal"
    "Pika Backup|org.gnome.World.PikaBackup"
)

print_status "Starting installation of ${#apps[@]} applications..."
echo "============================================"

# Install each application
for app in "${apps[@]}"; do
    IFS='|' read -r app_name app_id <<< "$app"
    total_apps=$((total_apps + 1))

    if install_flatpak "$app_name" "$app_id"; then
        successful_apps=$((successful_apps + 1))
    else
        failed_apps+=("$app_name")
    fi

    # Add a small delay to avoid overwhelming the system
    sleep 1
done

# Installation summary
echo ""
echo "============================================"
print_status "Installation Summary:"
echo "============================================"
echo "Total applications: $total_apps"
echo "Successfully installed: $successful_apps"
echo "Failed installations: $((total_apps - successful_apps))"

if [ ${#failed_apps[@]} -gt 0 ]; then
    echo ""
    print_warning "The following applications failed to install:"
    for failed_app in "${failed_apps[@]}"; do
        echo "  - $failed_app"
    done
    echo ""
    print_warning "You can try installing these manually with:"
    print_warning "flatpak install flathub <application-id>"
fi

echo ""
if [ $successful_apps -eq $total_apps ]; then
    print_success "All Flatpak applications installed successfully!"
else
    print_warning "$successful_apps out of $total_apps applications installed successfully."
fi

print_status "You can manage these applications using:"
echo "  - Flatseal (installed) - for managing permissions"
echo "  - Command line: flatpak list, flatpak update, flatpak uninstall"
echo "  - Your desktop environment's software center"

print_success "Flatpak installation script completed!"
