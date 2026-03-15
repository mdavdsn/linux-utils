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
        echo -e "${CYAN}${BOLD}$question [default: $default]${NC}" >&2
    else
        echo -e "${CYAN}${BOLD}$question${NC}" >&2
    fi
    read -r value
    echo "${value:-$default}"
}

# ── Helper: detect if AppImage is Electron-based ─────────────────────────────
is_electron_appimage() {
    local appimage_path="$1"

    # Fast path: use unsquashfs to list squashfs contents without full extraction.
    # --appimage-offset gives us the byte offset where squashfs starts in the file.
    if command -v unsquashfs &>/dev/null; then
        local offset
        offset=$("$appimage_path" --appimage-offset 2>/dev/null)
        if [[ "$offset" =~ ^[0-9]+$ ]]; then
            if unsquashfs -ll -offset "$offset" "$appimage_path" 2>/dev/null                     | grep -q 'chrome-sandbox'; then
                return 0
            else
                return 1
            fi
        fi
    fi

    # Slow fallback: full extraction. May take several seconds for large AppImages.
    warning "squashfs-tools not installed (sudo apt install squashfs-tools). Falling back to full extraction..." >&2
    local tmpdir prev_dir result=1
    tmpdir=$(mktemp -d)
    prev_dir="$PWD"
    cd "$tmpdir"

    "$appimage_path" --appimage-extract &>/dev/null

    if find "$tmpdir/squashfs-root" -name 'chrome-sandbox' -type f 2>/dev/null             | grep -q .; then
        result=0
    fi

    cd "$prev_dir"
    rm -rf "$tmpdir"
    return $result
}

# ── Helper: check if icon name resolves in the system icon theme ─────────────
icon_in_theme() {
    local icon_name="$1"
    [[ -z "$icon_name" ]] && return 1
    # Reject if it looks like a path rather than a name
    [[ "$icon_name" == */* ]] && return 1
    find /usr/share/icons /usr/share/pixmaps "$ICONS_DIR" \
        \( -name "${icon_name}.png" -o -name "${icon_name}.svg" \
           -o -name "${icon_name}.xpm" \) \
        2>/dev/null | grep -q .
}

# ── Helper: extract icon from AppImage and install into hicolor theme ─────────
extract_and_install_icon() {
    local appimage_path="$1"
    local icon_name="$2"
    local tmpdir prev_dir
    tmpdir=$(mktemp -d)
    prev_dir="$PWD"
    cd "$tmpdir"

    info "Extracting icon from AppImage (this may take a moment)..."

    # Full extraction is the only reliable approach — glob-based single-file
    # extraction is not consistently supported across AppImage runtimes.
    "$appimage_path" --appimage-extract &>/dev/null

    local icon_src=""

    # Prefer .DirIcon (the standard AppImage icon), then any root-level png/svg
    if [[ -f "$tmpdir/squashfs-root/.DirIcon" ]]; then
        icon_src="$tmpdir/squashfs-root/.DirIcon"
    else
        icon_src=$(find "$tmpdir/squashfs-root" -maxdepth 1 \
            \( -iname "*.png" -o -iname "*.svg" \) 2>/dev/null | head -1)
    fi

    if [[ -z "$icon_src" ]]; then
        warning "No icon found in AppImage."
        cd "$prev_dir"
        rm -rf "$tmpdir"
        return 1
    fi

    # Determine format and install into hicolor hierarchy
    local icon_ext dest_dir
    if file "$icon_src" 2>/dev/null | grep -qi "svg"; then
        icon_ext="svg"
        dest_dir="$ICONS_DIR/hicolor/scalable/apps"
    else
        icon_ext="png"
        dest_dir="$ICONS_DIR/hicolor/256x256/apps"
    fi

    mkdir -p "$dest_dir"
    cp "$icon_src" "$dest_dir/${icon_name}.${icon_ext}"

    # Refresh icon cache
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache -f -t "$ICONS_DIR/hicolor" 2>/dev/null
    fi

    cd "$prev_dir"
    rm -rf "$tmpdir"
    success "Icon installed: $dest_dir/${icon_name}.${icon_ext}"
    return 0
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
    SOURCE_PATH="${SOURCE_PATH/#\~/$HOME}"
    if [[ ! -f "$SOURCE_PATH" ]]; then
        error "File not found: $SOURCE_PATH"
        exit 1
    fi
else
    # Ask for directory, default to ~/Downloads
    SEARCH_DIR=$(ask_input "Directory containing AppImage" "~/Downloads")
    SEARCH_DIR="${SEARCH_DIR/#\~/$HOME}"

    if [[ ! -d "$SEARCH_DIR" ]]; then
        error "Directory not found: $SEARCH_DIR"
        exit 1
    fi

    # Find .AppImage files (case-insensitive)
    mapfile -t APPIMAGE_FILES < <(find "$SEARCH_DIR" -maxdepth 1 -iname "*.appimage" | sort)

    if [[ ${#APPIMAGE_FILES[@]} -eq 0 ]]; then
        error "No AppImage files found in $SEARCH_DIR"
        exit 1
    fi

    echo ""
    info "AppImage files found in $SEARCH_DIR:"
    echo ""
    for i in "${!APPIMAGE_FILES[@]}"; do
        echo -e "  ${CYAN}${BOLD}$((i+1))${NC}) $(basename "${APPIMAGE_FILES[$i]}")"
    done
    echo ""

    while true; do
        prompt "Select a file (1-${#APPIMAGE_FILES[@]}):"
        read -r selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && \
           [[ "$selection" -ge 1 ]] && \
           [[ "$selection" -le ${#APPIMAGE_FILES[@]} ]]; then
            SOURCE_PATH="${APPIMAGE_FILES[$((selection-1))]}"
            break
        else
            warning "Please enter a number between 1 and ${#APPIMAGE_FILES[@]}."
        fi
    done
fi

FILENAME=$(basename "$SOURCE_PATH")
info "Selected: $FILENAME"
echo ""

# ── Step 2: App name ──────────────────────────────────────────────────────────
# Derive a default name from filename (strip version numbers and extension)
DEFAULT_NAME=$(basename "$SOURCE_PATH" .AppImage \
    | sed -E 's/[-_][0-9]+\.[0-9]+(\.[0-9]+)*//g' \
    | sed -E 's/[-_](x86_64|aarch64|arm64|linux)//gi' \
    | sed 's/[-_]/ /g' \
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
# Must be executable before we can run --appimage-extract or --appimage-offset
chmod +x "$SOURCE_PATH"

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

success "AppImage is executable."

# ── Step 8: Resolve icon ─────────────────────────────────────────────────────
# Derive a sanitised icon name from the app name for use in hicolor
ICON_INSTALL_NAME=$(echo "$APP_NAME" | tr '[:upper:] ' '[:lower:]-' | tr -dc 'a-z0-9-')
ICON_PATH="$ICON"

if [[ -n "$ICON" ]] && icon_in_theme "$ICON"; then
    info "Icon '$ICON' found in system theme."
else
    if [[ -n "$ICON" ]]; then
        warning "Icon '$ICON' not found in system theme."
    fi
    info "Attempting to extract icon from AppImage..."
    if extract_and_install_icon "$DEST_PATH" "$ICON_INSTALL_NAME"; then
        ICON_PATH="$ICON_INSTALL_NAME"
    else
        warning "No icon could be resolved. The app will launch without one."
        ICON_PATH=""
    fi
fi

# ── Step 9: Write .desktop file ───────────────────────────────────────────────
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
    [[ -n "$ICON_PATH" ]] && echo "Icon=$ICON_PATH"
    echo "Type=Application"
    echo "Categories=$CATEGORIES"
    echo "Terminal=$TERMINAL"
    echo "StartupNotify=true"
} > "$DESKTOP_FILE"

chmod 755 "$DESKTOP_FILE"
success "Desktop entry created: $DESKTOP_FILE"

# ── Step 10: Refresh desktop database ─────────────────────────────────────────
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null && \
        info "Desktop database updated."
fi

# Rebuild KDE's application menu cache if running Plasma
if command -v kbuildsycoca6 &>/dev/null; then
    kbuildsycoca6 2>/dev/null && info "KDE application cache rebuilt."
elif command -v kbuildsycoca5 &>/dev/null; then
    kbuildsycoca5 2>/dev/null && info "KDE application cache rebuilt."
fi

echo ""
success "Done! $APP_NAME is ready to launch."
echo ""
