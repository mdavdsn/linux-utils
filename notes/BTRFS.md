# BTRFS Installation

This method of formatting a SSD/NVME drive for BTRFS will create subvolumes for root, home, snapshots, logs, and cache. These steps must be performed during installation.

## Debian Installation

1. Use the Debian Netinstall for computers with a wired internet connection. Otherwise, download the latest complete installation image. [Images can be downloaded here](https://www.debian.org/distrib/).
2. Copy the installation image to a Ventoy USB and boot the computer with the image.
3. Select the Advanced Install > Expert Install method.
4. Setup language, setup keyboard, detect and mount installation media, load installer components, autoconfigure the network (wired connection), setup users (skip root login), and configure the clock (NTP).
5. Detect disks.
6. Partiion the disks > Manual.
  1. Select primary disk.
  2. GPT table type.
  3. Create EFI partition (500MB) if necessary.
  4. Select free space, create new partition.
  5. Select BTRFS partition type.
  6. Finish partioning and write changes to disk.
  7. Skip swap partition.
7. CTRL+ALT+F2 to enter console.
8. Type `df -h`. Note the names of the `/target` and `/target/boot/efi` devices (`/dev/sda1` and `dev/sda2` here as examples).
```
~# df -h
Filesystem                    Size      Used Available Use% Mounted on
tmpfs                         6.3G    356.0K      6.3G   0% /run
devtmpfs                     31.6G         0     31.3G   0% /dev
none                        256.0K     84.1K    166.9K  33% /sys/firmware/efi/efivars
/dev/sda2                     1.5T      5.8M      1.5T   0% /target
/dev/sda1                    500MB      4.0K      500M   0% /target/boot/efi
~# _
```
9. Unmount all of the target disks.
```
# umount /target/boot/efi/
# umount /target/
```
10. Mount the disks to `/mnt`.
```
# mount /dev/dev/sda2 /mnt
# cd mnt
```
11. Rename the root subvolume.
```
# mv @rootfs @
```
12. Create the other subvolumes.
```
# btrfs su cr @home
# btrfs su cr @snapshots
# btrfs su cr @log
# btrfs su cr @cache
```
13. Mount the subvolumes to the appropriate direcotries.
```
/mnt # mount -o noatime,compress=zstd,subvol=@ /dev/sda2 /target
/mnt # mkdir -p /target/boot/efi
/mnt # mkdir -p /target/home
/mnt # mkdir -p /target/.snapshots
/mnt # mkdir -p /target/var/log
/mnt # mkdir -p /target/var/cache
/mnt # mount -o noatime,compress=zstd,subvol=@home /dev/sda2 /target/home
/mnt # mount -o noatime,compress=zstd,subvol=@snapshots /dev/sda2 /target/.snapshots
/mnt # mount -o noatime,compress=zstd,subvol=@log /dev/sda2 /target/var/log
/mnt # mount -o noatime,compress=zstd,subvol=@cache /dev/sda2 /target/var/cache
```
19. Mount the `/boot/efi`.
```
/mnt # mount /dev/sda1 /target/boot/efi
```
20. Edit fstab: `nano /target/etc/fstab`.
```
# <file system>                           <mount point>          <type> <options>                                                              <dump> <pass>
# was on /dev/sda2 during installation
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /                      btrfs  rw,noatime,compress=zstd,subvol=@                                      0       1
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /home                  btrfs  rw,noatime,compress=zstd,subvol=@home                                  0       2
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /.snapshots            btrfs  rw,noatime,compress=zstd,subvol=@snapshots                             0       2
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /var/logs              btrfs  rw,noatime,compress=zstd,subvol=@logs                                  0       2
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /var/cache             btrfs  rw,noatime,compress=zstd,subvol=@cache                                 0       2
# /boot/efi was on /dev/sda1 during installation
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /boot/efi              ufat   umask=000                                                   0       0
```
21. Write out the file with CTRL+X and "y" then continue with the installation with CTRL+ALT+F1.

## Ubuntu Installation

Use the Ubuntu Netboot for computers with a wired internet connection. Otherwise, download the latest complete installation image.
| Flavor         | Download Page                               |
| -------------- | ------------------------------------------- |
| Ubuntu (GNOME) | [Link](https://ubuntu.com/download/desktop) |
| Kubuntu (KDE)  | [Link](https://kubuntu.org/getkubuntu/)     |
| Lubuntu (LXQT) | [Link](https://lubuntu.me/downloads/)       |
| Xubuntu (XFCE) | [Link](https://xubuntu.org/download/)       |
| Ubuntu Studio  | [Link](https://ubuntustudio.org/)           |

1. Copy the installation image to a Ventoy USB and boot the computer with the image.
2. Boot to the live image and select the installation from the desktop.
3. Follow the installation wizard, selecting manual partioning.
  1. Select primary disk.
  2. GPT table type.
  3. Create EFI partition (500MB) if necessary.
  4. Select free space, create new partition.
  5. Select BTRFS partition type.
  6. Finish partioning and write changes to disk.
  7. Skip swap partition.
7. Complete the installation but do not remove the USB.
8. Boot back to the live image and open the terminal.
9. Type `df -h`. Note the names of the `/target` and `/target/boot/efi` devices (`/dev/sda1` and `dev/sda2` here as examples).
```
~# df -h
Filesystem                    Size      Used Available Use% Mounted on
tmpfs                         6.3G    356.0K      6.3G   0% /run
devtmpfs                     31.6G         0     31.3G   0% /dev
none                        256.0K     84.1K    166.9K  33% /sys/firmware/efi/efivars
/dev/sda2                     1.5T      5.8M      1.5T   0% /target
/dev/sda1                    500MB      4.0K      500M   0% /target/boot/efi
~# _
```
10. Unmount all of the target disks.
```
# umount /target/boot/efi/
# umount /target/
```
11. Mount the disks to `/mnt`.
```
# mount /dev/dev/sda2 /mnt
# cd mnt
```
12. the `@` and `@home` subvolumes have already been created, so create the other subvolumes manually.
```
# btrfs su cr @snapshots
# btrfs su cr @log
# btrfs su cr @cache
```
13. Mount the subvolumes to the appropriate direcotries.
```
/mnt # mount -o noatime,compress=zstd,subvol=@ /dev/sda2 /target
/mnt # mkdir -p /target/.snapshots
/mnt # mount -o noatime,compress=zstd,subvol=@home /dev/sda2 /target/home
/mnt # mount -o noatime,compress=zstd,subvol=@snapshots /dev/sda2 /target/.snapshots
/mnt # mount -o noatime,compress=zstd,subvol=@log /dev/sda2 /target/var/log
/mnt # mount -o noatime,compress=zstd,subvol=@cache /dev/sda2 /target/var/cache
```
14. Edit fstab: `nano /target/etc/fstab`.
```
# <file system>                           <mount point>          <type> <options>                                                              <dump> <pass>
# was on /dev/sda2 during installation
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /                      btrfs  rw,noatime,compress=zstd,subvol=@                                      0       1
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /home                  btrfs  rw,noatime,compress=zstd,subvol=@home                                  0       2
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /.snapshots            btrfs  rw,noatime,compress=zstd,subvol=@snapshots                             0       2
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /var/logs              btrfs  rw,noatime,compress=zstd,subvol=@logs                                  0       2
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /var/cache             btrfs  rw,noatime,compress=zstd,subvol=@cache                                 0       2
# /boot/efi was on /dev/sda1 during installation
UUID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX /boot/efi              ufat   umask=000                                                   0       0
```
15. Write out the file with CTRL+X and "y" then close the terminal and reboot. Remove the installation media when prompted and change the boot priority to the primary OS drive.
