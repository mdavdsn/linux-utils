#!/bin/bash

# Application Installation Script
# Interactive group/application selection (tasksel-style).
# Selecting a group header toggles all applications within that group.
# Supports Flatpak and AppImage installations transparently.
# Requires: dialog, Flatpak, Flathub repository already configured.

set -e

# ── Colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Actual user (works with or without sudo) ───────────────────────────────
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

print_status "Starting application installer..."
print_status "Installing for user: $ACTUAL_USER"

# ── Prerequisites ──────────────────────────────────────────────────────────
if ! command -v dialog &>/dev/null; then
    print_error "'dialog' is required but not installed."
    echo "  Fedora:        sudo dnf install dialog"
    echo "  Ubuntu/Debian: sudo apt install dialog"
    exit 1
fi

if ! command -v flatpak &>/dev/null; then
    print_error "Flatpak is not installed. Please install Flatpak first."
    exit 1
fi

if ! flatpak remotes 2>/dev/null | grep -q flathub; then
    print_error "Flathub is not configured."
    echo "  Add it with: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
    exit 1
fi

print_success "Flatpak and Flathub are available"

# ── Application catalogue ──────────────────────────────────────────────────
# Format: "GROUP_ID|Display Name|install_id"
# install_id: a Flatpak app ID, or a *_APPIMAGE token for AppImage apps.
catalogue=(
    # Audio & Video
    "AUDIO_VIDEO|Audacity|org.audacityteam.Audacity"
    "AUDIO_VIDEO|HandBrake|fr.handbrake.ghb"
    "AUDIO_VIDEO|Kdenlive|org.kde.kdenlive"
    "AUDIO_VIDEO|Kodi|tv.kodi.Kodi"
    "AUDIO_VIDEO|MuseScore Studio|MUSESCORE_APPIMAGE"
    "AUDIO_VIDEO|Podcasts|org.gnome.Podcasts"
    "AUDIO_VIDEO|Strawberry Music Player|org.strawberrymusicplayer.strawberry"
    "AUDIO_VIDEO|VLC Media Player|org.videolan.VLC"
    # Development
    "DEVELOPMENT|VSCodium|com.vscodium.codium"
    # Games
    "GAMES|ES-DE Frontend|ESDE_APPIMAGE"
    "GAMES|RetroArch|org.libretro.RetroArch"
    "GAMES|Steam|com.valvesoftware.Steam"
    # Graphics
    "GRAPHICS|FontBase|FONTBASE_APPIMAGE"
    "GRAPHICS|GIMP|org.gimp.GIMP"
    "GRAPHICS|Gwenview|org.kde.gwenview"
    "GRAPHICS|Inkscape|org.inkscape.Inkscape"
    "GRAPHICS|Krita|org.kde.krita"
    "GRAPHICS|Scribus|net.scribus.Scribus"
    "GRAPHICS|Upscayl|org.upscayl.Upscayl"
    # Internet
    "INTERNET|Discord|com.discordapp.Discord"
    "INTERNET|FileZilla|org.filezillaproject.Filezilla"
    "INTERNET|Firefox|org.mozilla.firefox"
    "INTERNET|Google Chrome|com.google.Chrome"
    "INTERNET|Slack|com.slack.Slack"
    "INTERNET|Thunderbird|org.mozilla.thunderbird"
    "INTERNET|Transmission|com.transmissionbt.Transmission"
    "INTERNET|Zoom|us.zoom.Zoom"
    # Office
    "OFFICE|Audiveris|org.audiveris.audiveris"
    "OFFICE|Okular|org.kde.okular"
    "OFFICE|OnlyOffice Desktop Editors|org.onlyoffice.desktopeditors"
    # System Tools
    "SYSTEM|Bitwarden|com.bitwarden.desktop"
    "SYSTEM|Flatseal|com.github.tchx84.Flatseal"
    "SYSTEM|KDE Calculator|org.kde.kalk"
    "SYSTEM|Pika Backup|org.gnome.World.PikaBackup"
)

# Group display order and labels
group_order=(AUDIO_VIDEO DEVELOPMENT GAMES GRAPHICS INTERNET OFFICE SYSTEM)

declare -A group_labels=(
    [AUDIO_VIDEO]="Audio & Video"
    [DEVELOPMENT]="Development"
    [GAMES]="Games"
    [GRAPHICS]="Graphics"
    [INTERNET]="Internet"
    [OFFICE]="Office"
    [SYSTEM]="System Tools"
)

# Parse catalogue into parallel indexed arrays
app_group=()
app_label=()
app_id=()
for entry in "${catalogue[@]}"; do
    IFS='|' read -r _g _l _i <<< "$entry"
    app_group+=("$_g")
    app_label+=("$_l")
    app_id+=("$_i")
done

# ── State ──────────────────────────────────────────────────────────────────
# Maps each tag ("GROUP_X" or an install_id) to "on" or "off".
declare -A state

for grp in "${group_order[@]}"; do
    state["GROUP_$grp"]="off"
done
for i in "${!app_id[@]}"; do
    state["${app_id[$i]}"]="off"
done

# ── Helper: derive group checkbox state from its children ──────────────────
# Group shows "on" only when every child is "on".
sync_group_state() {
    local grp=$1
    local all_on=true
    for i in "${!app_group[@]}"; do
        [[ "${app_group[$i]}" != "$grp" ]] && continue
        if [[ "${state[${app_id[$i]}]}" == "off" ]]; then
            all_on=false
            break
        fi
    done
    $all_on && state["GROUP_$grp"]="on" || state["GROUP_$grp"]="off"
}

# ── Interactive selection loop ─────────────────────────────────────────────
while true; do

    # Build the flat list of items for dialog --checklist
    dialog_items=()
    for grp in "${group_order[@]}"; do
        dialog_items+=(
            "GROUP_$grp"
            "══ ${group_labels[$grp]} ══"
            "${state[GROUP_$grp]}"
        )
        for i in "${!app_group[@]}"; do
            [[ "${app_group[$i]}" != "$grp" ]] && continue
            dialog_items+=(
                "${app_id[$i]}"
                "    ${app_label[$i]}"
                "${state[${app_id[$i]}]}"
            )
        done
    done

    result=$(dialog --stdout \
        --title " Application Installer " \
        --checklist \
        "SPACE to select/deselect  |  Select a group header to toggle all apps in that group\nPress ENTER when ready to install" \
        0 65 25 \
        "${dialog_items[@]}") || {
        clear
        print_warning "Installation cancelled."
        exit 0
    }

    # Parse dialog output into a lookup set
    unset new_sel; declare -A new_sel
    if [[ -n "$result" ]]; then
        eval "sel_array=($result)"
        for tag in "${sel_array[@]}"; do
            new_sel["$tag"]="on"
        done
    fi

    # Build full new_state from dialog output
    unset new_state; declare -A new_state
    for grp in "${group_order[@]}"; do
        new_state["GROUP_$grp"]="${new_sel[GROUP_$grp]:-off}"
    done
    for i in "${!app_id[@]}"; do
        new_state["${app_id[$i]}"]="${new_sel[${app_id[$i]}]:-off}"
    done

    # Propagate group-level toggles down to children
    needs_reshow=false
    for grp in "${group_order[@]}"; do
        old="${state[GROUP_$grp]}"
        new="${new_state[GROUP_$grp]}"
        if [[ "$old" != "$new" ]]; then
            for i in "${!app_group[@]}"; do
                [[ "${app_group[$i]}" != "$grp" ]] && continue
                new_state["${app_id[$i]}"]="$new"
            done
            needs_reshow=true
        fi
    done

    # Commit new state
    for key in "${!new_state[@]}"; do
        state["$key"]="${new_state[$key]}"
    done

    # Re-derive all group states from their children
    for grp in "${group_order[@]}"; do
        sync_group_state "$grp"
    done

    # If a group was toggled, re-show so the user sees updated children
    $needs_reshow && continue

    # Build confirmation list
    confirm_msg="The following applications will be installed:\n\n"
    any_selected=false
    for i in "${!app_id[@]}"; do
        [[ "${state[${app_id[$i]}]}" != "on" ]] && continue
        confirm_msg+="  \u2022 ${app_label[$i]}\n"
        any_selected=true
    done

    if ! $any_selected; then
        dialog --stdout --msgbox \
            "No applications selected.\nPlease select at least one application." \
            8 52
        continue
    fi

    confirm_msg+="\nProceed with installation?"
    dialog --stdout --yesno "$confirm_msg" 0 65 && break
done

clear

# ── AppImage install helper ────────────────────────────────────────────────
# Handles download, chmod, and .desktop entry creation for all AppImage apps.
# Usage: _appimage_install "App Name" "File.AppImage" "url" "icon" "Categories;" "Comment" ["extra exec args"]
_appimage_install() {
    local app_name="$1"
    local filename="$2"
    local download_url="$3"
    local icon="$4"
    local categories="$5"
    local comment="$6"
    local exec_args="${7:-}"

    local apps_dir="$ACTUAL_HOME/Applications"
    local install_path="$apps_dir/$filename"
    local desktop_dir="$ACTUAL_HOME/.local/share/applications"
    local desktop_file="$desktop_dir/${filename%.AppImage}.desktop"
    local exec_line="$install_path"
    [[ -n "$exec_args" ]] && exec_line="$install_path $exec_args"

    sudo -u "$ACTUAL_USER" mkdir -p "$apps_dir" "$desktop_dir"

    print_status "Downloading $app_name..."
    if command -v curl &>/dev/null; then
        sudo -u "$ACTUAL_USER" curl -L -o "$install_path" "$download_url" \
            || { print_error "Failed to download $app_name"; return 1; }
    else
        sudo -u "$ACTUAL_USER" wget -O "$install_path" "$download_url" \
            || { print_error "Failed to download $app_name"; return 1; }
    fi

    chmod +x "$install_path"

    sudo -u "$ACTUAL_USER" tee "$desktop_file" > /dev/null << EOF
[Desktop Entry]
Name=$app_name
Comment=$comment
Exec=$exec_line
Icon=$icon
Type=Application
Categories=$categories
Terminal=false
StartupNotify=true
EOF

    print_status "Desktop entry created at $desktop_file"
    return 0
}

# ── FontBase ───────────────────────────────────────────────────────────────
_install_fontbase() {
    local download_url=""

    print_status "Fetching latest FontBase version..."
    if command -v curl &>/dev/null; then
        download_url=$(curl -sL https://fontba.se/downloads/linux \
            | grep -oE 'https://releases\.fontba\.se/linux/FontBase-[^"]+\.AppImage' \
            | head -1) || true
    else
        download_url=$(wget -qO- https://fontba.se/downloads/linux \
            | grep -oE 'https://releases\.fontba\.se/linux/FontBase-[^"]+\.AppImage' \
            | head -1) || true
    fi

    if [[ -z "$download_url" ]]; then
        print_warning "Could not determine latest FontBase version. Using fallback."
        download_url="https://releases.fontba.se/linux/FontBase-2026.2.5.AppImage"
    fi

    _appimage_install \
        "FontBase" \
        "FontBase.AppImage" \
        "$download_url" \
        "fontbase" \
        "Graphics;" \
        "Professional font manager for designers and typographers" \
        "--no-sandbox"
}

# ── MuseScore Studio ───────────────────────────────────────────────────────
_install_musescore() {
    local arch
    arch=$(uname -m)

    print_status "Fetching latest MuseScore version from GitHub..."
    local api_response=""
    if command -v curl &>/dev/null; then
        api_response=$(curl -s https://api.github.com/repos/musescore/MuseScore/releases/latest) || true
    else
        api_response=$(wget -qO- https://api.github.com/repos/musescore/MuseScore/releases/latest) || true
    fi

    local download_url=""
    if [[ -n "$api_response" ]]; then
        download_url=$(echo "$api_response" \
            | grep '"browser_download_url"' \
            | grep "${arch}\.AppImage" \
            | sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/') || true
    fi

    if [[ -z "$download_url" ]]; then
        print_warning "Could not determine latest MuseScore URL for $arch. Using fallback."
        case "$arch" in
            aarch64) download_url="https://github.com/musescore/MuseScore/releases/download/v4.7.4/MuseScore-Studio-4.7.4.260706075-aarch64.AppImage" ;;
            *)       download_url="https://github.com/musescore/MuseScore/releases/download/v4.7.4/MuseScore-Studio-4.7.4.260706075-x86_64.AppImage" ;;
        esac
    fi

    _appimage_install \
        "MuseScore Studio" \
        "MuseScore.AppImage" \
        "$download_url" \
        "mscore" \
        "Audio;AudioVideo;Music;" \
        "Create, play and print beautiful sheet music"
}

# ── ES-DE Frontend ─────────────────────────────────────────────────────────
_install_esde() {
    local arch
    arch=$(uname -m)

    local download_url
    case "$arch" in
        x86_64)  download_url="https://gitlab.com/es-de/emulationstation-de/-/package_files/288156961/download" ;;
        aarch64) download_url="https://gitlab.com/es-de/emulationstation-de/-/package_files/326321114/download" ;;
        *)
            print_error "ES-DE: unsupported architecture $arch"
            return 1
            ;;
    esac

    _appimage_install \
        "ES-DE Frontend" \
        "ES-DE.AppImage" \
        "$download_url" \
        "emulationstation" \
        "Game;Emulator;" \
        "Emulation frontend for Linux"
}

# ── AppImage dispatcher ────────────────────────────────────────────────────
install_appimage() {
    case "$1" in
        FONTBASE_APPIMAGE)  _install_fontbase ;;
        MUSESCORE_APPIMAGE) _install_musescore ;;
        ESDE_APPIMAGE)      _install_esde ;;
        *)
            print_error "Unknown AppImage token: $1"
            return 1
            ;;
    esac
}

# ── host-spawn ─────────────────────────────────────────────────────────────
install_host_spawn() {
    print_status "Installing host-spawn utility..."

    local architecture
    architecture=$(uname -m)

    case "$architecture" in
        x86_64)      architecture="x86_64" ;;
        aarch64)     architecture="aarch64" ;;
        armv7l)      architecture="armv7" ;;
        riscv64)     architecture="riscv64" ;;
        loongarch64) architecture="loongarch64" ;;
        *)
            print_error "Unsupported architecture: $architecture"
            print_warning "host-spawn installation skipped."
            return 1
            ;;
    esac

    print_status "Fetching latest host-spawn version from GitHub..."
    local host_spawn_version=""

    if command -v curl &>/dev/null; then
        host_spawn_version=$(curl -s https://api.github.com/repos/1player/host-spawn/releases/latest \
            | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/') || true
    elif command -v wget &>/dev/null; then
        host_spawn_version=$(wget -qO- https://api.github.com/repos/1player/host-spawn/releases/latest \
            | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/') || true
    fi

    if [[ -z "$host_spawn_version" ]]; then
        print_warning "Could not determine latest version. Falling back to v1.6.2"
        host_spawn_version="v1.6.2"
    fi

    local download_url="https://github.com/1player/host-spawn/releases/download/${host_spawn_version}/host-spawn-${architecture}"
    local install_path="/usr/local/bin/host-spawn"

    print_status "Downloading host-spawn ${host_spawn_version} for ${architecture}..."

    if command -v curl &>/dev/null; then
        curl -L -o /tmp/host-spawn "$download_url" \
            || { print_error "Failed to download host-spawn"; return 1; }
    else
        wget -O /tmp/host-spawn "$download_url" \
            || { print_error "Failed to download host-spawn"; return 1; }
    fi

    if [[ -w /usr/local/bin ]]; then
        mv /tmp/host-spawn "$install_path"
        chmod +x "$install_path"
    else
        sudo mv /tmp/host-spawn "$install_path"
        sudo chmod +x "$install_path"
    fi

    print_success "host-spawn installed to $install_path"
    print_status "Run host commands from Flatpak containers with: host-spawn <command>"
    return 0
}

# ── AppImage Manager ───────────────────────────────────────────────────────
install_appimage_manager() {
    print_status "Installing AppImage Manager..."

    local pip_cmd=""
    if command -v pip3 &>/dev/null; then
        pip_cmd="pip3"
    elif command -v pip &>/dev/null; then
        pip_cmd="pip"
    else
        print_warning "pip not found. Skipping AppImage Manager."
        print_warning "Install pip and retry: pip3 install --user appimagemanager"
        return 1
    fi

    if sudo -u "$ACTUAL_USER" "$pip_cmd" install --user appimagemanager; then
        print_success "AppImage Manager installed"
        return 0
    else
        print_warning "Failed to install AppImage Manager."
        print_warning "You can install it manually: pip3 install --user appimagemanager"
        return 1
    fi
}

# ── Install selected applications ──────────────────────────────────────────
echo "============================================"
echo " Installing selected applications"
echo "============================================"
echo ""

total=0
success=0
failed=()

for i in "${!app_id[@]}"; do
    id="${app_id[$i]}"
    [[ "${state[$id]}" != "on" ]] && continue

    lbl="${app_label[$i]}"
    total=$((total + 1))
    print_status "Installing $lbl..."

    install_ok=false
    if [[ "$id" == *_APPIMAGE ]]; then
        install_appimage "$id" && install_ok=true
    else
        sudo -u "$ACTUAL_USER" flatpak install -y flathub "$id" && install_ok=true
    fi

    if $install_ok; then
        print_success "$lbl installed"
        success=$((success + 1))
    else
        print_error "Failed to install $lbl"
        failed+=("$lbl")
    fi

    sleep 1
done

# ── host-spawn (only when VSCodium is selected) ────────────────────────────
if [[ "${state[com.vscodium.codium]}" == "on" ]]; then
    echo ""
    echo "============================================"
    echo " Installing host-spawn (required by VSCodium)"
    echo "============================================"
    install_host_spawn || true
fi

# ── AppImage Manager (automatic) ───────────────────────────────────────────
echo ""
echo "============================================"
echo " Installing AppImage Manager"
echo "============================================"
install_appimage_manager || true

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
print_status "Installation Summary"
echo "============================================"
echo "Total applications: $total"
echo "Successfully installed: $success"
echo "Failed: $((total - success))"

if [[ ${#failed[@]} -gt 0 ]]; then
    echo ""
    print_warning "The following applications failed to install:"
    for f in "${failed[@]}"; do
        echo "  - $f"
    done
    echo ""
    print_warning "You can retry Flatpak apps manually with:"
    print_warning "  flatpak install flathub <application-id>"
fi

echo ""
if [[ $success -eq $total ]]; then
    print_success "All selected applications installed successfully!"
else
    print_warning "$success of $total applications installed successfully."
fi

print_status "You can manage your applications with:"
echo "  - Flatseal (if installed)   — manage Flatpak permissions"
echo "  - AppImage Manager          — manage AppImage applications"
echo "  - host-spawn <command>      — run host commands from Flatpak containers"
echo "  - flatpak list / update / uninstall"

print_success "Installation script completed!"
