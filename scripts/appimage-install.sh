#!/bin/bash

# AppImage Installer
# Moves an AppImage to ~/Applications and creates a .desktop entry

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
prompt()  { echo -e "${CYAN}${BOLD}$1${NC}"; }

# ── Directories ───────────────────────────────────────────────────────────────
APPS_DIR="$HOME/Applications"
DESKTOP_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons"

# ── XDG Categories (for reference prompt) ────────────────────────────────────
CATEGORY_HINT="Common categories: AudioVideo, Audio, Video, Development, Education,
  Game, Graphics, Network, Office, Science, Settings, System, Utility"

# ── Helper: yes/no prompt ─────────────────────────────────────────────────────
ask_yn() {
    local question="$1"
    local default="${2:-n}"
    local yn_label
    if [[ "$default" == "y" ]]; then yn_label="[Y/n]"; else yn_label="[y/N]"; fi
    while true; do
        prompt "$question $yn_label"
        read -r answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) warning "Please answer y or n." ;;
        esac
    done
}

# ── Helper: read with optional default ───────────────────────────────────────
ask_input() {
    local question="$1"
    local default="$2"
    local value
    if [[ -n "$default" ]]; then
        prompt "$question [default: $default]"
    else
        prompt "$question"
    fi
    read -r value
    echo "${value:-$default}"
}

# ── Helper: detect if AppImage is Electron-based ─────────────────────────────
is_electron_appimage() {
    local appimage_path="$1"
    local tmpdir
    tmpdir=$(mktemp -d)

    # Try to extract just enough of the AppImage to check for electron marker
    # offset 0 = squashfs, we look for 'electron' string in the binary header area
    if strings "$appimage_path" 2>/dev/null | grep -qi "electron"; then
        rm -rf "$tmpdir"
        return 0
    fi

    rm -rf "$tmpdir"
    return 1
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════╗${NC}"
echo -e "${BOLD}║      AppImage Installer          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Resolve AppImage path ─────────────────────────────────────────────
if [[ -n "$1" ]]; then
    SOURCE_PATH="$1"
else
    prompt "Path to AppImage file:"
    read -r SOURCE_PATH
fi

# Expand ~ if present
SOURCE_PATH="${SOURCE_PATH/#\~/$HOME}"

if [[ ! -f "$SOURCE_PATH" ]]; then
    error "File not found: $SOURCE_PATH"
    exit 1
fi

if [[ "${SOURCE_PATH##*.}" != "AppImage" && "${SOURCE_PATH##*.}" != "appimage" ]]; then
    warning "File does not have an .AppImage extension. Continuing anyway..."
fi

FILENAME=$(basename "$SOURCE_PATH")
info "Found: $FILENAME"
echo ""

# ── Step 2: App name ──────────────────────────────────────────────────────────
# Derive a default name from filename (strip version numbers and extension)
DEFAULT_NAME=$(basename "$SOURCE_PATH" .AppImage \
    | sed -E 's/[-_][0-9]+\.[0-9]+(\.[0-9]+)*//g' \
    | sed -E 's/[-_](x86_64|aarch64|arm64|linux)//gi' \
    | tr '-_' ' ' \
    | sed 's/  */ /g' \
    | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}')

APP_NAME=$(ask_input "App name" "$DEFAULT_NAME")
echo ""

# ── Step 3: Destination filename ──────────────────────────────────────────────
# Suggest a clean filename: no spaces, preserve original extension
DEFAULT_DEST_NAME=$(echo "$APP_NAME" | tr ' ' '-').AppImage
DEST_NAME=$(ask_input "Filename in ~/Applications" "$DEFAULT_DEST_NAME")
DEST_PATH="$APPS_DIR/$DEST_NAME"

echo ""

# ── Step 4: Electron / --no-sandbox detection ─────────────────────────────────
NO_SANDBOX=false
info "Checking if AppImage is Electron-based..."
if is_electron_appimage "$SOURCE_PATH"; then
    warning "Electron-based AppImage detected."
    echo "  Electron apps may fail to launch due to Chromium sandbox restrictions"
    echo "  on systems where /tmp is mounted nosuid (common on Ubuntu-based distros)."
    echo ""
    if ask_yn "Add --no-sandbox flag to launcher?" "y"; then
        NO_SANDBOX=true
        success "--no-sandbox will be added to the Exec line."
    fi
else
    info "No Electron markers detected."
    echo ""
    if ask_yn "Add --no-sandbox anyway? (only needed for Electron apps)" "n"; then
        NO_SANDBOX=true
    fi
fi
echo ""

# ── Step 5: Desktop entry metadata ────────────────────────────────────────────
echo -e "${BOLD}── Desktop Entry Details ─────────────────────────────────────────${NC}"
echo ""

COMMENT=$(ask_input "Short description (Comment field)" "")
echo ""

echo "$CATEGORY_HINT"
echo ""
CATEGORIES=$(ask_input "Categories (semicolon-separated)" "Utility")
# Ensure trailing semicolon
[[ "$CATEGORIES" != *";" ]] && CATEGORIES="${CATEGORIES};"
echo ""

ICON=$(ask_input "Icon name or path (leave blank to skip)" "")
echo ""

TERMINAL=false
if ask_yn "Run in a terminal window?" "n"; then
    TERMINAL=true
fi
echo ""

# ── Step 6: Confirm ───────────────────────────────────────────────────────────
echo -e "${BOLD}── Summary ───────────────────────────────────────────────────────${NC}"
echo "  Source:      $SOURCE_PATH"
echo "  Destination: $DEST_PATH"
echo "  App name:    $APP_NAME"
echo "  Comment:     ${COMMENT:-"(none)"}"
echo "  Categories:  $CATEGORIES"
echo "  Icon:        ${ICON:-"(none)"}"
echo "  Terminal:    $TERMINAL"
echo "  --no-sandbox: $NO_SANDBOX"
echo ""

if ! ask_yn "Proceed with installation?" "y"; then
    info "Aborted."
    exit 0
fi
echo ""

# ── Step 7: Move AppImage ─────────────────────────────────────────────────────
mkdir -p "$APPS_DIR"

if [[ "$SOURCE_PATH" != "$DEST_PATH" ]]; then
    if [[ -f "$DEST_PATH" ]]; then
        if ask_yn "  $DEST_PATH already exists. Overwrite?" "n"; then
            cp "$SOURCE_PATH" "$DEST_PATH"
            info "Copied (original kept in place)."
        else
            error "Destination already exists. Aborting."
            exit 1
        fi
    else
        mv "$SOURCE_PATH" "$DEST_PATH"
        info "Moved to $DEST_PATH"
    fi
fi

chmod +x "$DEST_PATH"
success "AppImage is executable."

# ── Step 8: Write .desktop file ───────────────────────────────────────────────
mkdir -p "$DESKTOP_DIR"

# Build Exec line
EXEC_LINE="$DEST_PATH"
$NO_SANDBOX && EXEC_LINE="$DEST_PATH --no-sandbox"

# Sanitise app name for desktop file name (lowercase, no spaces)
DESKTOP_FILENAME=$(echo "$APP_NAME" | tr '[:upper:] ' '[:lower:]-' | tr -dc 'a-z0-9-').desktop
DESKTOP_FILE="$DESKTOP_DIR/$DESKTOP_FILENAME"

{
    echo "[Desktop Entry]"
    echo "Name=$APP_NAME"
    [[ -n "$COMMENT" ]] && echo "Comment=$COMMENT"
    echo "Exec=$EXEC_LINE"
    [[ -n "$ICON" ]] && echo "Icon=$ICON"
    echo "Type=Application"
    echo "Categories=$CATEGORIES"
    echo "Terminal=$TERMINAL"
    echo "StartupNotify=true"
} > "$DESKTOP_FILE"

chmod 644 "$DESKTOP_FILE"
success "Desktop entry created: $DESKTOP_FILE"

# ── Step 9: Refresh desktop database ─────────────────────────────────────────
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null && \
        info "Desktop database updated."
fi

echo ""
success "Done! $APP_NAME is ready to launch."
echo ""
