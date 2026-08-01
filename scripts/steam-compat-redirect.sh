#!/bin/bash
# Redirects the shared Steam library's compatdata folder to this user's
# own private prefix storage, so Proton data never gets cross-owned.

SHARED_COMPAT="/srv/Files/steam/steamapps/compatdata"
USER_COMPAT="$HOME/.local/share/steam-private-compatdata"

mkdir -p "$USER_COMPAT"

if [ -L "$SHARED_COMPAT" ]; then
    rm -f "$SHARED_COMPAT"
elif [ -e "$SHARED_COMPAT" ]; then
    # Real directory present, not a symlink - don't touch it automatically.
    echo "steam-compat-redirect: $SHARED_COMPAT is a real directory, not a symlink. Refusing to overwrite - run the one-time migration first." >&2
    exit 1
fi

ln -s "$USER_COMPAT" "$SHARED_COMPAT"
