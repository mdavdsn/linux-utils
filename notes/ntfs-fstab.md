# Fstab Entries for NTFS volumes

Pattern:

```bash
UUID=UUID-OF-VOLUME  /path/to/mountpoint   ntfs3   uid=1000,gid=1000,umask=0022,nofail,x-gvfs-show  0  0
```

Get the UUID:

```bash
lsblk -f
```

Create the mount point:

```bash
sudo mkdir -p /path/to/mountpoint
sudo chown $USER:$USER /path/to/mountpoint
```

Add the fstab entry:

```bash
sudo nano /etc/fstab
```

Enter the volume information using the pattern above.
