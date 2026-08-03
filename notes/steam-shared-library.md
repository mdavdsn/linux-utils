# Shared Steam Library Setup (Multi-User, Ubuntu 26.04, Flatpak Steam)

Guide for sharing a single Steam library (games installed once) across multiple Linux user accounts on the same machine, where each account runs its own Steam login under **Steam Families**. Covers both an **ext4** shared drive and an **NTFS** shared drive (e.g. a drive also used by a dual-boot Windows install).

Prerequisits:
- Ubuntu/Kubuntu 26.04+
- Steam installed as a **system-wide** Flatpak (`com.valvesoftware.Steam`)
- Multiple local user accounts, each with their own Steam login, joined to the same Steam Family

---

## Why this is needed

- Flatpak sandboxes filesystem access — Steam needs an explicit override to read/write a shared library path outside each user's home.
- Proton/Wine prefixes (`compatdata`) are **single-owner** by design. `wineserver` refuses to use a prefix directory it doesn't own, so a shared library's `compatdata` folder can't simply be shared read/write across accounts — each user needs their own private prefix, transparently swapped in.

---

## Shared Library on ext4

Use this when the shared drive/partition is formatted ext4 (e.g. a repurposed internal SSD partition).

### 1. Create a shared group

```bash
sudo groupadd steamlib
sudo usermod -aG steamlib user1
sudo usermod -aG steamlib user2
sudo usermod -aG steamlib user3
```

Log out/in (or reboot) on each account so group membership takes effect.

### 2. Create and mount the shared directory

Prefer `/srv/<name>` over `/media` or `/mnt` — `/srv` is the correct FHS location for permanent, system-provided data, and avoids conflicts with desktop automount services (`udisks2`/`gvfs`) that actively manage `/media/<user>/...` paths and can delete/recreate directories out from under a static `fstab` entry.

```bash
sudo mkdir -p /srv/Games
```

Get the partition's UUID:

```bash
sudo blkid
```

Add to `/etc/fstab` (back it up first):

```bash
sudo cp /etc/fstab /etc/fstab.bak
```

```
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /srv/Games  ext4  defaults  0  2
```

Test and mount:

```bash
sudo systemctl daemon-reload
sudo mount -a
df -h /srv/Games
```

### 3. Set ownership and permissions

```bash
sudo chown root:steamlib /srv/Games
sudo chmod 2775 /srv/Games
sudo setfacl -d -m g:steamlib:rwx /srv/Games
sudo setfacl -d -m o::rx /srv/Games
```

The setgid bit (`2775`) and default ACL ensure every file/folder any of the three accounts creates stays group-writable by the others.

### 4. Grant the Flatpak sandbox access

```bash
sudo flatpak override --system com.valvesoftware.Steam --filesystem=/srv/Games
```

`--system` applies the override to **every account** on the machine in one command.

### 5. Add the library folder in Steam (each account)

**Steam → Settings → Storage → ⋮ → Add Drive**, point to `/srv/Games/steam/SteamLibrary`.

Install each shared game once from any account. The other accounts will see it as already installed once they add the same library folder — no re-download, just a quick file verification.

---

## Shared Library on NTFS

Use this when the shared drive is NTFS (e.g. shared with a dual-boot Windows 11 install).

### Key difference from ext4

NTFS has no native Unix ownership concept. The `ntfs3` driver **fakes** a single uniform owner/group/permission set for the *entire mount*, controlled entirely by the `uid=`/`gid=`/`umask=` mount options — there is no per-file `chown`/ACL step here.

### 1. Create the shared group (if not already done)

```bash
sudo groupadd steamlib
sudo usermod -aG steamlib user1
sudo usermod -aG steamlib user2
sudo usermod -aG steamlib user3
getent group steamlib   # note the GID — it is independent per machine
```

### 2. Mount point and fstab entry

Avoid `/media/<user>/...` — it's actively managed by `udisks2`/`gvfs` and will conflict with a static `fstab` entry (directories can be removed/recreated by the automount service, breaking `mount -a`). Use `/srv/<name>` instead:

```bash
sudo mkdir -p /srv/Games
```

Back up and edit fstab:

```bash
sudo cp /etc/fstab /etc/fstab.bak
```

```
UUID=XXXXXXXXXXXXXXXX  /srv/Games  ntfs3  uid=1000,gid=<steamlib_gid>,umask=0002,nofail  0  0
```

Notes on the options:
- `uid=1000` — sets the reported owner for every file on the mount to this UID (adjust to your primary account's actual UID).
- `gid=<steamlib_gid>` — reported group for every file; must be the `steamlib` GID **on this machine** (GIDs are not guaranteed to match across machines even with the same group name).
- `umask=0002` — gives **owner and group** full read/write (`775` dirs / `664` files). Do **not** use `umask=0022` — that leaves the drive writable only by the mount's designated `uid=` owner, blocking other accounts from installing or updating games.
- `nofail` — prevents boot failure if the drive isn't present.

Apply and test:

```bash
sudo systemctl daemon-reload
sudo mount -a
mount | grep Games
```

> **If `mount -a` reports `mount point does not exist` unexpectedly:** check the *entire* `/etc/fstab` for stale or malformed lines — the error can point to an unrelated broken entry elsewhere in the file, not the line you just edited. `cat -A /etc/fstab` will reveal hidden/merged lines or bad line breaks.

### 3. Grant the Flatpak sandbox access

```bash
sudo flatpak override --system com.valvesoftware.Steam --filesystem=/srv/Games
```

### 4. Add the library folder in Steam (each account)

Same as the ext4 case: **Steam → Settings → Storage → Add Drive**, point to `/srv/Games/steam/SteamLibrary`.

### 5. Windows dual-boot caveat

If Windows 11 has **Fast Startup** enabled, it can leave NTFS in a "hibernated" state that Linux refuses to mount read-write. Disable it in Windows: **Control Panel → Power Options → Choose what the power buttons do → uncheck Fast Startup.**

---

## Per-User Proton `compatdata` Redirect (Required on Both Filesystems)

This part is identical regardless of whether the shared library is ext4 or NTFS, because the underlying cause is the same: Wine prefixes are single-owner, and `wineserver` will refuse to run against a prefix directory it doesn't own.

> **Do not skip this for any account, including whichever account originally installed the games.** Ownership of the shared `compatdata` symlink gets reassigned to whichever account most recently logged in and ran the redirect script — if an account doesn't have the script installed, it will eventually inherit a symlink pointing at someone else's private prefix data and fail the ownership check too.

### 1. One-time migration (run once, on the account that originally installed the games)

Move the real `compatdata` folder out of the shared library into that account's own private Flatpak data directory, then replace it with a symlink:

```bash
mkdir -p ~/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/compatdata
rsync -a /srv/Games/steamapps/compatdata/ ~/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/compatdata/
rm -rf /srv/Games/steamapps/compatdata
ln -s ~/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/compatdata /srv/Games/steamapps/compatdata
```

Verify it's a symlink:

```bash
ls -la /srv/Games/steamapps/ | grep compatdata
```

### 2. Install the redirect script (on every account, including the one above)

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/steam-compat-redirect.sh << 'EOF'
#!/bin/bash
# Redirects the shared Steam library's compatdata folder to this user's
# own private prefix storage inside Steam's flatpak sandbox data dir.

SHARED_COMPAT="/srv/Games/steam/SteamLibrary/steamapps/compatdata"
USER_COMPAT="$HOME/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/compatdata"

mkdir -p "$USER_COMPAT"

if [ -L "$SHARED_COMPAT" ]; then
    rm -f "$SHARED_COMPAT"
elif [ -e "$SHARED_COMPAT" ]; then
    # Real directory present, not a symlink - don't touch it automatically.
    echo "steam-compat-redirect: $SHARED_COMPAT is a real directory, not a symlink. Refusing to overwrite - run the one-time migration first." >&2
    exit 1
fi

ln -s "$USER_COMPAT" "$SHARED_COMPAT"
EOF
chmod +x ~/.local/bin/steam-compat-redirect.sh
```

The script deliberately refuses to run if it finds a real directory instead of a symlink, so it can't silently destroy prefix data if something is in an unexpected state.

### 3. Add an autostart entry (on every account)

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/steam-compat-redirect.desktop << 'EOF'
[Desktop Entry]
Type=Application
Exec=bash -c "$HOME/.local/bin/steam-compat-redirect.sh"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Steam Compatdata Redirect
Comment=Points the shared Steam library's compatdata to this user's private prefix folder
EOF
```

The `bash -c "$HOME/..."` wrapper lets this be identical, copy-pasteable text on every account — `$HOME` expands per-session at run time.

### 4. Run it once manually on each account (don't wait for a reboot)

```bash
~/.local/bin/steam-compat-redirect.sh
```

---

## Important Limitation: No Fast User Switching

Only one symlink can point to `/srv/Games/steam/SteamLibrary/steamapps/compatdata` at a time. If a second account logs in via **fast user switching** without the first account fully logging out, whichever account logged in last "wins" the symlink for as long as both sessions remain active — potentially pointing a running game at the wrong prefix mid-session.

**Always fully log out before switching users on this setup**, rather than using fast user switching.

---

## Quick Reference: Command Summary

| Task | ext4 | NTFS |
|---|---|---|
| Shared group | `groupadd steamlib` + `usermod -aG` | Same |
| Permissions | `chown`, `chmod 2775`, `setfacl` on the directory | `uid=`/`gid=`/`umask=0002` in the `fstab` mount options |
| Mount point | `/srv/<name>` (not `/media`, not `/mnt`) | Same |
| Flatpak override | `flatpak override --system ... --filesystem=/srv/<name>` | Same |
| Steam library folder | Added identically in each account's Steam client | Same |
| `compatdata` redirect | Required on every account | Required on every account |
