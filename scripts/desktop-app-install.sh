#!/bin/bash

# Flatpak Applications Installation Script
# This script automates the installation of essential Flatpak applications
# and host-spawn utility for running host commands from containers
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

# Function to install host-spawn
install_host_spawn() {
    print_status "Installing host-spawn utility..."
    
    # Detect architecture
    local architecture
    architecture=$(uname -m)
    
    # Map architecture names to host-spawn release naming
    case "$architecture" in
        x86_64)
            architecture="x86_64"
            ;;
        aarch64)
            architecture="aarch64"
            ;;
        armv7l)
            architecture="armv7"
            ;;
        riscv64)
            architecture="riscv64"
            ;;
        loongarch64)
            architecture="loongarch64"
            ;;
        *)
            print_error "Unsupported architecture: $architecture"
            print_warning "host-spawn installation skipped. Continuing with Flatpak installations..."
            return 1
            ;;
    esac
    
    # Fetch the latest version from GitHub API
    print_status "Fetching latest host-spawn version from GitHub..."
    local host_spawn_version
    
    if command -v curl &> /dev/null; then
        host_spawn_version=$(curl -s https://api.github.com/repos/1player/host-spawn/releases/latest | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    elif command -v wget &> /dev/null; then
        host_spawn_version=$(wget -qO- https://api.github.com/repos/1player/host-spawn/releases/latest | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    else
        print_error "Neither curl nor wget is available. Cannot fetch latest version."
        print_warning "Falling back to version v1.6.2"
        host_spawn_version="v1.6.2"
    fi
    
    # Validate that we got a version
    if [ -z "$host_spawn_version" ]; then
        print_warning "Could not determine latest version. Falling back to v1.6.2"
        host_spawn_version="v1.6.2"
    fi
    
    local download_url="https://github.com/1player/host-spawn/releases/download/${host_spawn_version}/host-spawn-${architecture}"
    local install_path="/usr/local/bin/host-spawn"
    
    print_status "Downloading host-spawn ${host_spawn_version} for ${architecture}..."
    
    # Download to temporary location
    if command -v curl &> /dev/null; then
        if ! curl -L -o /tmp/host-spawn "$download_url"; then
            print_error "Failed to download host-spawn"
            return 1
        fi
    elif command -v wget &> /dev/null; then
        if ! wget -O /tmp/host-spawn "$download_url"; then
            print_error "Failed to download host-spawn"
            return 1
        fi
    else
        print_error "Neither curl nor wget is available. Cannot download host-spawn."
        return 1
    fi
    
    # Install to /usr/local/bin
    print_status "Installing host-spawn to $install_path..."
    if [ -w /usr/local/bin ]; then
        mv /tmp/host-spawn "$install_path"
        chmod +x "$install_path"
    else
        sudo mv /tmp/host-spawn "$install_path"
        sudo chmod +x "$install_path"
    fi
    
    print_success "host-spawn installed successfully to $install_path"
    print_status "You can now run host commands from Flatpak containers using: host-spawn <command>"
    return 0
}

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

echo "============================================"
echo "Step 1: Installing Flatpak applications"
echo "============================================"
print_status "Starting installation of ${#apps[@]} applications..."
echo ""

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

# Install host-spawn after Flatpak applications
echo ""
echo "============================================"
echo "Step 2: Installing host-spawn utility"
echo "============================================"
install_host_spawn
echo ""

# Function to install FontBase AppImage
install_fontbase() {
    print_status "Installing FontBase AppImage..."

    local user_home
    user_home=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
    local apps_dir="$user_home/Applications"
    local install_path="$apps_dir/FontBase.AppImage"
    local desktop_dir="$user_home/.local/share/applications"
    local desktop_file="$desktop_dir/fontbase.desktop"

    # Create ~/Applications directory if it doesn't exist
    sudo -u "$ACTUAL_USER" mkdir -p "$apps_dir"

    # Try to fetch the latest download URL from FontBase download page
    print_status "Fetching latest FontBase version..."
    local download_url=""

    if command -v curl &> /dev/null; then
        download_url=$(curl -sL https://fontba.se/downloads/linux | grep -oE 'https://releases\.fontba\.se/linux/FontBase-[^"]+\.AppImage' | head -1)
    elif command -v wget &> /dev/null; then
        download_url=$(wget -qO- https://fontba.se/downloads/linux | grep -oE 'https://releases\.fontba\.se/linux/FontBase-[^"]+\.AppImage' | head -1)
    fi

    # Fall back to known version if URL could not be determined
    if [ -z "$download_url" ]; then
        print_warning "Could not determine latest FontBase version. Falling back to known version."
        download_url="https://releases.fontba.se/linux/FontBase-2026.2.5.AppImage"
    fi

    print_status "Downloading FontBase from $download_url..."

    if command -v curl &> /dev/null; then
        if ! sudo -u "$ACTUAL_USER" curl -L -o "$install_path" "$download_url"; then
            print_error "Failed to download FontBase"
            return 1
        fi
    elif command -v wget &> /dev/null; then
        if ! sudo -u "$ACTUAL_USER" wget -O "$install_path" "$download_url"; then
            print_error "Failed to download FontBase"
            return 1
        fi
    else
        print_error "Neither curl nor wget is available. Cannot download FontBase."
        return 1
    fi

    chmod +x "$install_path"
    print_success "FontBase installed to $install_path"

    # Create .desktop entry
    print_status "Creating FontBase desktop entry..."
    sudo -u "$ACTUAL_USER" mkdir -p "$desktop_dir"

    sudo -u "$ACTUAL_USER" tee "$desktop_file" > /dev/null <<EOF
[Desktop Entry]
Name=FontBase
Comment=Professional font manager for designers and typographers
Exec=$install_path --no-sandbox
Icon=fontbase
Type=Application
Categories=Graphics;
Terminal=false
StartupNotify=true
EOF

    print_success "Desktop entry created at $desktop_file"
    return 0
}

echo "============================================"
echo "Step 3: Installing FontBase AppImage"
echo "============================================"
install_fontbase
echo ""

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
echo "  - host-spawn - run host commands from Flatpak: host-spawn <command>"
echo "  - Command line: flatpak list, flatpak update, flatpak uninstall"
echo "  - Your desktop environment's software center"

print_success "Flatpak installation script completed!"
