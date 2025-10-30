#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Gulp CLI Installation Script ==="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for Node.js
echo "Checking for Node.js..."
if command_exists node; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js is installed: $NODE_VERSION${NC}"
else
    echo -e "${YELLOW}Node.js is not installed. Installing...${NC}"

    # Detect package manager
    if command_exists apt-get; then
        # Debian/Ubuntu
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command_exists yum; then
        # RHEL/CentOS/Fedora
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
        sudo yum install -y nodejs
    elif command_exists dnf; then
        # Fedora (newer versions)
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
        sudo dnf install -y nodejs
    elif command_exists pacman; then
        # Arch Linux
        sudo pacman -S --noconfirm nodejs npm
    else
        echo -e "${RED}✗ Could not detect package manager. Please install Node.js manually.${NC}"
        exit 1
    fi

    if command_exists node; then
        echo -e "${GREEN}✓ Node.js installed successfully${NC}"
    else
        echo -e "${RED}✗ Node.js installation failed${NC}"
        exit 1
    fi
fi

# Check for npm
echo ""
echo "Checking for npm..."
if command_exists npm; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✓ npm is installed: $NPM_VERSION${NC}"
else
    echo -e "${RED}✗ npm is not installed (this shouldn't happen with modern Node.js)${NC}"
    exit 1
fi

# Check for npx
echo ""
echo "Checking for npx..."
if command_exists npx; then
    NPX_VERSION=$(npx --version)
    echo -e "${GREEN}✓ npx is installed: $NPX_VERSION${NC}"
else
    echo -e "${YELLOW}npx is not installed (this is unusual for modern npm)${NC}"
    echo "npx should be included with npm 5.2.0+. Your npm might be outdated."
fi

# Install Gulp CLI globally
echo ""
echo "Installing Gulp CLI globally..."
if sudo npm install -g gulp-cli; then
    echo -e "${GREEN}✓ Gulp CLI installed successfully${NC}"
else
    echo -e "${RED}✗ Gulp CLI installation failed${NC}"
    exit 1
fi

# Verify Gulp installation
echo ""
echo "Verifying Gulp installation..."
if command_exists gulp; then
    GULP_VERSION=$(gulp --version)
    echo -e "${GREEN}✓ Gulp CLI is ready:${NC}"
    echo "$GULP_VERSION"
else
    echo -e "${RED}✗ Gulp command not found after installation${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo "You can now use 'gulp' command in your projects."
