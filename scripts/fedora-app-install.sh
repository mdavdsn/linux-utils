#!/bin/bash

# Fedora Software Installation Script
# This script automates the installation of essential development and system tools
# Targets a fresh Fedora 44 desktop installation
# Run with sudo privileges

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

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run with sudo privileges"
    echo "Usage: sudo $0"
    exit 1
fi

# Get the actual username (not root when using sudo)
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

print_status "Starting Fedora software installation script..."
print_status "Running as: $ACTUAL_USER"

# Enable RPM Fusion repositories (required for unrar and other non-free packages)
print_status "Enabling RPM Fusion repositories..."
dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || {
    print_error "Failed to enable RPM Fusion repositories"
    exit 1
}
print_success "RPM Fusion repositories enabled"

# Update package repositories and upgrade existing packages
print_status "Updating system packages..."
dnf upgrade -y || {
    print_error "Failed to update system packages"
    exit 1
}
print_success "System packages updated"

# Install development tools group (equivalent of build-essential)
print_status "Installing development tools group..."
dnf group install -y "Development Tools" || {
    print_error "Failed to install Development Tools group"
    exit 1
}
print_success "Development Tools group installed"

# Install kernel headers and devel
print_status "Installing kernel headers..."
dnf install -y "kernel-devel-$(uname -r)" || {
    print_warning "Exact kernel-devel not found, installing latest available..."
    dnf install -y kernel-devel || {
        print_error "Failed to install kernel headers"
        exit 1
    }
}
print_success "Kernel headers installed"

# Install additional compilation dependencies
print_status "Installing additional development tools..."
dnf install -y \
    cmake \
    autoconf \
    automake \
    libtool \
    pkgconf-pkg-config \
    openssl-devel \
    zlib-devel \
    bzip2-devel \
    readline-devel \
    sqlite-devel \
    wget \
    curl \
    llvm \
    ncurses-devel \
    xz \
    xz-devel \
    tk-devel \
    libffi-devel \
    qt6-qtbase-devel \
    qt6-qtsvg-devel \
    kf6-kwindowsystem-devel || {
    print_error "Failed to install development tools"
    exit 1
}
print_success "Additional development tools installed"

# Install file compression tools
print_status "Installing file compression tools..."
dnf install -y \
    unzip \
    p7zip \
    p7zip-plugins \
    unrar || {
    print_error "Failed to install compression tools"
    exit 1
}
print_success "File compression tools installed"

# Install Git
print_status "Installing Git..."
dnf install -y git || {
    print_error "Failed to install Git"
    exit 1
}
print_success "Git installed"

# Install Node.js and npm
print_status "Installing Node.js and npm..."
NODESOURCE_SETUP=$(mktemp)
if curl -fsSL https://rpm.nodesource.com/setup_lts.x -o "$NODESOURCE_SETUP"; then
    bash "$NODESOURCE_SETUP"
    rm -f "$NODESOURCE_SETUP"
    dnf install -y nodejs || {
        print_error "Failed to install Node.js from NodeSource"
        exit 1
    }
else
    print_warning "Failed to fetch NodeSource setup script, falling back to Fedora packages"
    rm -f "$NODESOURCE_SETUP"
    dnf install -y nodejs npm || {
        print_error "Failed to install Node.js and npm"
        exit 1
    }
fi
print_success "Node.js $(node --version) and npm $(npm --version) installed"

# Install Flatpak (pre-installed on Fedora Workstation, ensure it's present)
print_status "Installing Flatpak..."
dnf install -y flatpak || {
    print_error "Failed to install Flatpak"
    exit 1
}
print_success "Flatpak installed"

# Add Flathub repository
print_status "Adding Flathub repository..."
sudo -u "$ACTUAL_USER" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || {
    print_warning "Failed to add Flathub repository for user, trying system-wide..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || {
        print_error "Failed to add Flathub repository"
        exit 1
    }
}
print_success "Flathub repository added"

# Install Variety (wallpaper changer)
print_status "Installing Variety..."
dnf install -y variety || {
    print_error "Failed to install Variety"
    exit 1
}
print_success "Variety installed"

# Install Timeshift (system backup tool)
print_status "Installing Timeshift..."
dnf install -y timeshift || {
    print_error "Failed to install Timeshift"
    exit 1
}
print_success "Timeshift installed"

# Install zram-generator
print_status "Checking for zram-generator..."
if rpm -q zram-generator &>/dev/null; then
    print_status "zram-generator is already installed, skipping installation"
else
    print_status "Installing zram-generator..."
    dnf install -y zram-generator || {
        print_error "Failed to install zram-generator"
        exit 1
    }
    print_success "zram-generator installed"
fi

# Configure zram (Fedora uses zram-generator, which is included with systemd)
# zram is enabled by default on Fedora; this customizes the configuration
print_status "Configuring zram..."
ZRAM_CONFIG="/etc/systemd/zram-generator.conf"

if [ -f "$ZRAM_CONFIG" ]; then
    print_status "Existing zram configuration found, updating it..."
    cp "$ZRAM_CONFIG" "${ZRAM_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backed up existing configuration"

    # Update existing configuration values
    sed -i 's/^zram-size\s*=.*/zram-size = ram \/ 2/' "$ZRAM_CONFIG"
    sed -i 's/^compression-algorithm\s*=.*/compression-algorithm = lz4/' "$ZRAM_CONFIG"
    sed -i 's/^swap-priority\s*=.*/swap-priority = 100/' "$ZRAM_CONFIG"

    # Add missing parameters under [zram0] section if absent
    if ! grep -q "^\[zram0\]" "$ZRAM_CONFIG"; then
        echo "" >> "$ZRAM_CONFIG"
        echo "[zram0]" >> "$ZRAM_CONFIG"
    fi
    if ! grep -q "^zram-size" "$ZRAM_CONFIG"; then
        echo "zram-size = ram / 2" >> "$ZRAM_CONFIG"
    fi
    if ! grep -q "^compression-algorithm" "$ZRAM_CONFIG"; then
        echo "compression-algorithm = lz4" >> "$ZRAM_CONFIG"
    fi
    if ! grep -q "^swap-priority" "$ZRAM_CONFIG"; then
        echo "swap-priority = 100" >> "$ZRAM_CONFIG"
    fi

    print_success "zram configuration updated"
else
    print_status "Creating new zram configuration..."
    cat > "$ZRAM_CONFIG" << EOF
# zram-generator configuration
# See zram-generator.conf(5) for details

[zram0]
# Use half of available RAM for zram swap
zram-size = ram / 2

# Compression algorithm (lzo, lz4, zstd, lzo-rle)
compression-algorithm = lz4

# Priority for zram swap
swap-priority = 100
EOF
    print_success "zram configuration created"
fi

# Install dnfdragora (GUI package manager, Fedora equivalent of Synaptic)
print_status "Installing dnfdragora (GUI package manager)..."
dnf install -y dnfdragora || {
    print_error "Failed to install dnfdragora"
    exit 1
}
print_success "dnfdragora installed"

# Install Filelight (disk usage analyzer)
print_status "Installing Filelight..."
dnf install -y filelight || {
    print_error "Failed to install Filelight"
    exit 1
}
print_success "Filelight installed"

# Install Kvantum (Qt theme engine — available in Fedora repos, no PPA needed)
print_status "Installing Kvantum..."
dnf install -y kvantum || {
    print_error "Failed to install Kvantum"
    exit 1
}
print_success "Kvantum installed"

# Clean up
print_status "Cleaning up package cache..."
dnf autoremove -y
dnf clean all
print_success "Package cache cleaned"

# Display installed versions
print_status "Installation Summary:"
echo "===================="
echo "Git version: $(git --version)"
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
echo "GCC version: $(gcc --version | head -n1)"
echo "Flatpak version: $(flatpak --version)"
echo "Variety: $(sudo -u "$ACTUAL_USER" variety --version 2>/dev/null || echo 'Installed')"
echo "Timeshift version: $(timeshift --version 2>/dev/null || echo 'Installed')"
echo "dnfdragora: $(rpm -q dnfdragora 2>/dev/null || echo 'Installed')"
echo "Filelight: $(rpm -q filelight 2>/dev/null || echo 'Installed')"
echo "Kvantum: $(rpm -q kvantum 2>/dev/null || echo 'Installed')"
echo "===================="

print_success "All software installations completed successfully!"
print_warning "Note: You may need to restart your session for some changes to take effect."
print_warning "zram swap will be applied after reboot (or run: systemctl daemon-reload && systemctl restart systemd-zram-setup@zram0.service)"

print_success "Script execution completed!"
