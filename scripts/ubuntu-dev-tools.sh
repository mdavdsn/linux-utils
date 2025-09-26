#!/bin/bash

# Ubuntu Software Installation Script
# This script automates the installation of essential development and system tools
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

print_status "Starting Ubuntu software installation script..."
print_status "Running as: $ACTUAL_USER"

# Update package repositories
print_status "Updating package repositories..."
apt update -y || {
    print_error "Failed to update package repositories"
    exit 1
}
print_success "Package repositories updated"

# Upgrade existing packages
print_status "Upgrading existing packages..."
DEBIAN_FRONTEND=noninteractive apt upgrade -y || {
    print_error "Failed to upgrade packages"
    exit 1
}
print_success "System packages upgraded"

# Install build-essential and compilation tools
print_status "Installing build-essential and compilation tools..."
apt install -y build-essential || {
    print_error "Failed to install build-essential"
    exit 1
}
print_success "build-essential installed"

# Install kernel headers
print_status "Installing kernel headers..."
apt install -y linux-headers-$(uname -r) || {
    print_error "Failed to install kernel headers"
    exit 1
}
print_success "Kernel headers installed"

# Install additional compilation dependencies (not covered by build-essential)
print_status "Installing additional development tools..."
apt install -y \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    curl \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    qt6-base-dev \
    qt6-svg-dev \
    libkf6windowsystem-dev || {
    print_error "Failed to install development tools"
    exit 1
}
print_success "Additional development tools installed"

# Install file compression tools (if not already present in base installation)
print_status "Installing file compression tools..."
apt install -y \
    unzip \
    p7zip-full \
    unrar || {
    print_error "Failed to install compression tools"
    exit 1
}
print_success "File compression tools installed"

# Install Git
print_status "Installing Git..."
apt install -y git || {
    print_error "Failed to install Git"
    exit 1
}
print_success "Git installed"

# Install Node.js and npm
print_status "Installing Node.js and npm..."
# Install NodeSource repository for latest LTS Node.js
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - || {
    print_warning "Failed to add NodeSource repository, falling back to default packages"
    apt install -y nodejs npm || {
        print_error "Failed to install Node.js and npm"
        exit 1
    }
}

# Install Node.js and npm from NodeSource if repository was added successfully
if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
    apt update -y
    apt install -y nodejs || {
        print_error "Failed to install Node.js from NodeSource"
        exit 1
    }
else
    apt install -y nodejs npm || {
        print_error "Failed to install Node.js and npm"
        exit 1
    }
fi
print_success "Node.js and npm installed"

# Install Flatpak
print_status "Installing Flatpak..."
apt install -y flatpak || {
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
apt install -y variety || {
    print_error "Failed to install Variety"
    exit 1
}
print_success "Variety installed"

# Install Timeshift (system backup tool)
print_status "Installing Timeshift..."
apt install -y timeshift || {
    print_error "Failed to install Timeshift"
    exit 1
}
print_success "Timeshift installed"

# Install zram-tools
print_status "Installing zram-tools..."
apt install -y zram-tools || {
    print_error "Failed to install zram-tools"
    exit 1
}
print_success "zram-tools installed"

# Install Synaptic Package Manager
print_status "Installing Synaptic Package Manager..."
apt install -y synaptic || {
    print_error "Failed to install Synaptic"
    exit 1
}
print_success "Synaptic Package Manager installed"

# Install Filelight (disk usage analyzer)
print_status "Installing Filelight..."
apt install -y filelight || {
    print_error "Failed to install Filelight"
    exit 1
}
print_success "Filelight installed"

# Configure zram (creates or modifies configuration)
print_status "Configuring zram..."
ZRAM_CONFIG="/etc/default/zramswap"

if [ -f "$ZRAM_CONFIG" ]; then
    print_status "Existing zram configuration found, updating it..."
    # Backup existing configuration
    cp "$ZRAM_CONFIG" "${ZRAM_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backed up existing configuration"

    # Update existing configuration
    sed -i 's/^ALGO=.*/ALGO=lz4/' "$ZRAM_CONFIG"
    sed -i 's/^PERCENT=.*/PERCENT=50/' "$ZRAM_CONFIG"
    sed -i 's/^SIZE=.*/SIZE=2048/' "$ZRAM_CONFIG"
    sed -i 's/^PRIORITY=.*/PRIORITY=100/' "$ZRAM_CONFIG"

    # Add any missing parameters
    if ! grep -q "^ALGO=" "$ZRAM_CONFIG"; then
        echo "ALGO=lz4" >> "$ZRAM_CONFIG"
    fi
    if ! grep -q "^PERCENT=" "$ZRAM_CONFIG"; then
        echo "PERCENT=50" >> "$ZRAM_CONFIG"
    fi
    if ! grep -q "^SIZE=" "$ZRAM_CONFIG"; then
        echo "SIZE=2048" >> "$ZRAM_CONFIG"
    fi
    if ! grep -q "^PRIORITY=" "$ZRAM_CONFIG"; then
        echo "PRIORITY=100" >> "$ZRAM_CONFIG"
    fi

    print_success "zram configuration updated"
else
    print_status "Creating new zram configuration..."
    cat > "$ZRAM_CONFIG" << EOF
# Compression algorithm (lzo, lz4, zstd, lzo-rle)
ALGO=lz4

# Percentage of RAM to use for zram
PERCENT=50

# Maximum zram size in MB
SIZE=2048

# Priority for zram swap
PRIORITY=100
EOF
    print_success "zram configuration created"
fi

# Clean up
print_status "Cleaning up package cache..."
apt autoremove -y
apt autoclean
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
echo "Synaptic: $(dpkg -l synaptic 2>/dev/null | grep '^ii' | awk '{print $3}' || echo 'Installed')"
echo "Filelight: $(dpkg -l filelight 2>/dev/null | grep '^ii' | awk '{print $3}' || echo 'Installed')"
echo "===================="

print_success "All software installations completed successfully!"
print_warning "Note: You may need to restart your session for some changes to take effect."
print_warning "zram swap should be automatically started by the zramswap service"

print_success "Script execution completed!"
