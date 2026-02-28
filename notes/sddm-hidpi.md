# Enable HiDPI in SDDM Greeter
By default, the SDDM greeter is set to display at the native resolution of the monitor, making 2K and higher resolution monitors display the greeter too small. In order to fix this, add an configuration to the SDDM configuration directory. Source: [Arch Wiki](https://wiki.archlinux.org/title/SDDM#Enable_HiDPI)

1. Using a root account or administrator file manager, create a new file: `/etc/sddm.conf.d/hidpi.conf`.
2. Edit this file and add the following:
```
[Wayland]
EnableHiDPI=true

[X11]
EnableHiDPI=true

[General]
GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=2,QT_FONT_DPI=192
```
3. Save and exit the file.

## Additional Notes
Customize the scale factor and font DPI to a comfortable setting for your monitor. Here are a few common settings:

| Resolution | Monitor Size | Scale Factor | Font DPI | Logical Resolution |
| ---------- | ------------ | ------------ | -------- | ------------------ |
| 1920 x 1080, 1920 x 1200 | 10 - 15 in. | 1.5 | 144 | 1280 x 720, 1280 x 800 |
| 2560 x 1440, 2560 x 1600 | 15 - 21 in | 2 | 192 | 1280 x 720, 1280 x 800 |
| 3840 x 2160, 3840 x 2400 | 16 - 24 in | 2 | 192 | 1920 x 1080, 1920 x 1200 |
| 3840 x 2160, 3840 x 2400 | 16 - 24 in | 2.5 | 240 | 1536 x 864, 1536 x 960 |
