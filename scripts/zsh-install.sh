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

# Install neofetch
print_status "Installing neofetch..."
apt install -y neofetch || {
    print_error "Failed to install neofetch"
    exit 1
}
print_success "neofetch installed successfully"

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

if [ -f "$ZSHRC_FILE" ]; then
    # Backup existing .zshrc
    sudo -u "$ACTUAL_USER" cp "$ZSHRC_FILE" "$ZSHRC_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backed up existing .zshrc"
fi

# Create or modify .zshrc with essembeh theme and neofetch
sudo -u "$ACTUAL_USER" cat > "$ZSHRC_FILE" << 'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="essembeh"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications.
# For more details, see 'man strftime' for format specifiers.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git colored-man-pages command-not-found)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though users
# are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Run neofetch on shell startup
neofetch
EOF

print_success ".zshrc configured with essembeh theme and neofetch"

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
echo "neofetch: $(neofetch --version 2>/dev/null | head -n1 || echo 'Installed')"
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
