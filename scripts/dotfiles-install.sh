#!/bin/bash

# Dotfiles Installation Script
# Installs nano configuration for the current user and for root.
# OS-agnostic (pure file copy, no package manager involved) — works
# unmodified on Ubuntu/Kubuntu and Fedora.
# Run with sudo privileges (writes to /root and sets ownership)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run with sudo privileges"
    echo "Usage: sudo $0"
    exit 1
fi

# Get the actual username (not root when using sudo)
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

print_status "Starting dotfiles installation..."
print_status "Installing for user: $ACTUAL_USER"

if [ ! -f "$CONFIG_DIR/nanorc" ]; then
    print_error "Could not find $CONFIG_DIR/nanorc"
    exit 1
fi

# nano config — home folder
print_status "Installing ~/.nanorc for $ACTUAL_USER..."
if [ -f "$ACTUAL_HOME/.nanorc" ]; then
    sudo -u "$ACTUAL_USER" cp "$ACTUAL_HOME/.nanorc" "$ACTUAL_HOME/.nanorc.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backed up existing ~/.nanorc"
fi
sudo -u "$ACTUAL_USER" cp "$CONFIG_DIR/nanorc" "$ACTUAL_HOME/.nanorc"
print_success "$ACTUAL_HOME/.nanorc installed"

# nano config — root. Same base config as the home folder, with the
# title/status bar colors overridden to magenta (nanorc-root) so a root
# shell is visually distinct from a regular user shell. Later 'set'
# directives in a .nanorc override earlier ones for the same option, so
# concatenating nanorc-root after nanorc keeps everything else (line
# numbers, keybindings, syntax highlighting) and just recolors the bars.
if [ ! -f "$CONFIG_DIR/nanorc-root" ]; then
    print_error "Could not find $CONFIG_DIR/nanorc-root"
    exit 1
fi

print_status "Installing /root/.nanorc..."
if [ -f /root/.nanorc ]; then
    cp /root/.nanorc "/root/.nanorc.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backed up existing /root/.nanorc"
fi
cat "$CONFIG_DIR/nanorc" "$CONFIG_DIR/nanorc-root" > /root/.nanorc
print_success "/root/.nanorc installed"

print_success "Dotfiles installation completed!"
