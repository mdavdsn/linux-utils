#!/bin/bash

# Zsh and Oh My Zsh Setup Script
# This script installs zsh, Oh My Zsh, and neofetch, then configures them
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

print_status "Starting zsh setup script..."
print_status "Configuring for user: $ACTUAL_USER"
print_status "User home directory: $ACTUAL_HOME"

# Update package repositories
print_status "Updating package repositories..."
apt update -y || {
    print_error "Failed to update package repositories"
    exit 1
}

# Install zsh
print_status "Installing zsh..."
apt install -y zsh || {
    print_error "Failed to install zsh"
    exit 1
}
print_success "zsh installed successfully"

# Install fastfetch
print_status "Installing fastfetch..."
apt install -y fastfetch || {
    print_error "Failed to install fastfetch"
    exit 1
}
print_success "fastfetch installed successfully"

# Install curl and git if not already present (required for Oh My Zsh)
print_status "Installing dependencies for Oh My Zsh..."
apt install -y curl git || {
    print_error "Failed to install curl and git"
    exit 1
}
print_success "Dependencies installed"

# Install Oh My Zsh for the user
print_status "Installing Oh My Zsh..."
if [ ! -d "$ACTUAL_HOME/.oh-my-zsh" ]; then
    # Download and run Oh My Zsh installer as the actual user
    sudo -u "$ACTUAL_USER" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
        print_error "Failed to install Oh My Zsh"
        exit 1
    }
    print_success "Oh My Zsh installed successfully"
else
    print_warning "Oh My Zsh is already installed"
fi

# Check if essembeh theme exists, if not download it
print_status "Setting up essembeh theme..."
THEME_FILE="$ACTUAL_HOME/.oh-my-zsh/themes/essembeh.zsh-theme"
if [ ! -f "$THEME_FILE" ]; then
    print_status "Downloading essembeh theme..."
    sudo -u "$ACTUAL_USER" curl -fsSL "https://raw.githubusercontent.com/essembeh/oh-my-zsh-essembeh-theme/master/essembeh.zsh-theme" -o "$THEME_FILE" || {
        print_error "Failed to download essembeh theme"
        exit 1
    }
    print_success "essembeh theme downloaded"
else
    print_warning "essembeh theme already exists"
fi

# Configure .zshrc
print_status "Configuring .zshrc..."
ZSHRC_FILE="$ACTUAL_HOME/.zshrc"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

if [ ! -f "$CONFIG_DIR/zshrc" ]; then
    print_error "Could not find $CONFIG_DIR/zshrc"
    exit 1
fi

if [ -f "$ZSHRC_FILE" ]; then
    # Backup existing .zshrc
    sudo -u "$ACTUAL_USER" cp "$ZSHRC_FILE" "$ZSHRC_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backed up existing .zshrc"
fi

sudo -u "$ACTUAL_USER" cp "$CONFIG_DIR/zshrc" "$ZSHRC_FILE"

print_success ".zshrc installed from linux-utils/config/zshrc"

# Set zsh as the default shell for the user
print_status "Setting zsh as default shell for $ACTUAL_USER..."
chsh -s $(which zsh) "$ACTUAL_USER" || {
    print_error "Failed to change default shell to zsh"
    exit 1
}
print_success "Default shell changed to zsh for $ACTUAL_USER"

# Set proper ownership for all files
print_status "Setting proper file ownership..."
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.oh-my-zsh" "$ACTUAL_HOME/.zshrc" 2>/dev/null || true
print_success "File ownership set correctly"

# Display installation summary
print_status "Installation Summary:"
echo "===================="
echo "zsh version: $(zsh --version)"
echo "Oh My Zsh: Installed in $ACTUAL_HOME/.oh-my-zsh"
echo "Theme: essembeh"
echo "fastfetch: $(neofetch --version 2>/dev/null | head -n1 || echo 'Installed')"
echo "Default shell: $(getent passwd "$ACTUAL_USER" | cut -d: -f7)"
echo "===================="

print_success "Zsh setup completed successfully!"
print_warning "Please log out and log back in, or run 'su - $ACTUAL_USER' to start using zsh"
print_warning "You can also run 'zsh' to test the new shell immediately"

# Offer to start zsh immediately
echo ""
read -p "Would you like to start a zsh session now to test the setup? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Starting zsh session..."
    sudo -u "$ACTUAL_USER" zsh -l
fi

print_success "Script execution completed!"
