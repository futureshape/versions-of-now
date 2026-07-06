# Dali Clock on HyperPixel 4.0 Square

This install turns a Raspberry Pi into a dedicated clock that runs the native
Linux/X11 `xdaliclock` app full-screen on a Pimoroni HyperPixel 4.0 Square
display at boot.

The setup deliberately stays simple:

- Raspberry Pi OS Lite, configured with Raspberry Pi Imager.
- Built-in Raspberry Pi kernel drivers for the HyperPixel Square.
- Minimal X11 session with `xdaliclock --root`.
- A locked local `xdaliclock` user run by a dedicated systemd service on
  `tty1`.

## Hardware Assumptions

- Raspberry Pi with a 40-pin GPIO header.
- Pimoroni HyperPixel 4.0 Square, preferably the newer `HyperPixel XP` square
  board required by the current kernel driver.
- Network access during installation for APT packages.
- A valid Raspberry Pi system clock. Raspberry Pi OS network time sync is
  enough for normal use; add an RTC if the clock must keep correct time without
  network access.

The HyperPixel uses the DPI interface and consumes most GPIO pins, including the
normal I2C pins. Do not plan to use other GPIO HATs on the same Pi.

## Hands-Off SD-Card Setup

For the least manual setup, use `image-sd-card.sh` from a computer with a card
reader and Raspberry Pi Imager installed. This writes Raspberry Pi OS Lite and
injects a first-boot script that configures Wi-Fi, the admin user, and
`xdaliclock`.

The wrapper also keeps the SD card mounted after Imager writes it and adds
`bootfs/userconf.txt` plus the `bootfs/ssh` marker. This follows Raspberry Pi's
documented manual headless setup: Raspberry Pi OS consumes `userconf.txt` on
first boot to create the admin user non-interactively, and the empty `ssh` file
enables the SSH server. Without `userconf.txt`, `userconf-pi` can stop at a
text UI asking which user to rename.

On macOS, the script auto-detects the normal app-bundle executable at
`/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager`.

1. Copy the local settings template:

   ```sh
   cp rpi/xdaliclock-hyperpixel-square/sd-card.env.example \
     rpi/xdaliclock-hyperpixel-square/sd-card.env
   ```

2. Edit `rpi/xdaliclock-hyperpixel-square/sd-card.env`.

   At minimum, set:

   - `PI_ADMIN_PASSWORD`
   - `PI_WIFI_SSID` and `PI_WIFI_PASSWORD`, unless using Ethernet
   - `PI_WIFI_COUNTRY`
   - `PI_TIMEZONE`

   If using `SSH_AUTHORIZED_KEYS_FILE`, set it to an absolute path.

3. Find the SD-card device.

   On macOS:

   ```sh
   diskutil list
   ```

   On Linux:

   ```sh
   lsblk
   ```

4. Write the card. The destination device is destructive.

   ```sh
   rpi/xdaliclock-hyperpixel-square/image-sd-card.sh /dev/rdiskN
   ```

   Use `/dev/rdiskN` on macOS or `/dev/sdX` / `/dev/mmcblkN` on Linux,
   replacing the example with the SD-card device found in the previous step.

5. Insert the card into the Pi and power it on.

First boot can take several minutes. It connects to the network, installs
packages, configures the HyperPixel overlay, reboots, and then starts
`xdaliclock`. SSH is enabled by the `bootfs/ssh` marker before the first-boot
installer runs.

`sd-card.env` is gitignored because it can contain Wi-Fi and login secrets.

## Manual SD-Card Setup

1. Flash a microSD card with Raspberry Pi Imager.
2. Choose `Raspberry Pi OS Lite (64-bit)`.
3. In Imager settings, configure Wi-Fi, enable SSH, and set a normal admin user.
4. Boot the Pi once and SSH into it.
5. Copy this folder to the Pi:

   ```sh
   scp -r rpi/xdaliclock-hyperpixel-square <user>@<pi-hostname>.local:/tmp/
   ```

6. Run the installer on the Pi:

   ```sh
   ssh <user>@<pi-hostname>.local
   cd /tmp/xdaliclock-hyperpixel-square
   sudo ./install.sh
   sudo reboot
   ```

After the reboot, the Pi should start `xdaliclock` on the HyperPixel display
without keyboard, mouse, SSH, browser, or website intervention.

## What the Installer Changes

For manual installs, `install.sh` does the following:

- Installs minimal display packages with APT: Xorg, xinit, xauth, X11
  utilities, GLib's `gsettings` tool, X11 core bitmap fonts (`xfonts-base`),
  and the Debian `xdaliclock` package.
- Ensures `/boot/firmware/config.txt` contains:
  - `dtoverlay=vc4-kms-v3d`
  - `dtoverlay=vc4-kms-dpi-hyperpixel4sq,rotate=270`
  - `dtparam=i2c_arm=off`
  - `dtparam=spi=off`
- Runs `raspi-config nonint do_i2c 1` and `raspi-config nonint do_spi 1` when
  available, matching Pimoroni's guidance to disable interfaces that conflict
  with HyperPixel.
- Creates a locked `xdaliclock` user.
- Configures `xdaliclock.service` to own `tty1` and start X directly.
- Masks `getty@tty1` so the display is reserved for the clock.
- Launches the native app as `xdaliclock --root`, which draws directly on the
  X root window.
- Defaults to 24-hour time display via `XDALICLOCK_HOURMODE="24"` in
  `/etc/default/xdaliclock-session`.
- Applies `xrandr --output DPI-1 --rotate left` at session start to rotate the
  framebuffer 270 degrees, matching the HyperPixel Square's physical
  orientation. The DPI overlay's `rotate=270` parameter is not automatically
  reflected by the modesetting X driver, so both settings are kept in step.
- Writes `/etc/X11/xorg.conf.d/99-xdaliclock-input.conf` to suppress the
  HyperPixel's built-in touchscreen in X, preventing incidental taps from
  triggering xdaliclock's date-display toggle.

For automated SD-card imaging, `image-sd-card.sh` writes `userconf.txt` and an
empty `ssh` file to the card before first boot. This enables headless SSH and
prevents Raspberry Pi OS from opening the interactive first-user rename dialog.
HyperPixel boot config is still handled by `install.sh` during first-run
provisioning.

## Troubleshooting First Boot

If the Pi reaches an ordinary console login instead of starting `xdaliclock`,
the first-boot provisioning probably did not complete. Mount the SD card's boot
partition on another computer and check:

```sh
cat /Volumes/bootfs/xdaliclock-firstboot.log
```

On a running Pi, the same log is normally at:

```sh
sudo cat /boot/firmware/xdaliclock-firstboot.log
```

If the log does not exist, Raspberry Pi Imager did not install or run the
first-run script. If the log stops before `first boot provisioning complete`,
the last `[xdaliclock-firstboot]` or `[xdaliclock-install]` line should show the
step that failed, usually Wi-Fi, DNS, APT, or package installation.

APT errors that say repository signatures are `Not live until ...` mean the Pi
had network before its clock had synced. The installer waits for NTP before APT
and retries package-list refreshes, but a very slow network can still make first
boot take several minutes.

If the log ends with `first boot provisioning complete` but the display still
shows a console login after the reboot, first-boot installation has finished and
the remaining problem is the `tty1` service/X startup path. SSH in as the admin
user and check:

```sh
sudo systemctl status xdaliclock.service --no-pager
sudo systemctl cat xdaliclock.service
sudo journalctl -b -u xdaliclock.service --no-pager
sudo journalctl -b --no-pager | grep -Ei 'xdaliclock|startx|xorg|tty1'
sudo cat /home/xdaliclock/.local/share/xorg/Xorg.0.log
```


The command arguments can be changed later in `/etc/default/xdaliclock-session`.
The upstream man page documents only these runtime options:

- `--root`: render on the root window instead of opening an application window.
- `--display host:display.screen`: choose an X display.
- `--window-id number`: render inside an existing X11 window.
- `--version`: print the version number and exit.

Do not put preferences such as `-24` in `XDALICLOCK_ARGS`; `xdaliclock` will
exit because those are not command-line options. The installer exposes common
preferences in the same file as GSettings-backed variables:

```sh
XDALICLOCK_ARGS="--root"
XDALICLOCK_HOURMODE="24"
XDALICLOCK_TIMEMODE="HHMMSS"
XDALICLOCK_DATEMODE="DDMMYY"
XDALICLOCK_FOREGROUND="#0000FF"
XDALICLOCK_BACKGROUND="#00B3B3FF"
XDALICLOCK_CYCLESPEED="15"
```

The HyperPixel kernel overlay accepts a `rotate` parameter:

```sh
dtoverlay=vc4-kms-dpi-hyperpixel4sq,rotate=270
```

This sets the panel orientation in the DRM subsystem and correctly orients the
Linux text console before X starts. However, the modesetting X driver does not
automatically inherit this rotation, so `xdaliclock-xsession` applies a
matching xrandr rotation at X startup:

```sh
xrandr --output DPI-1 --rotate left
```

Both settings are kept in step. If the physical mount orientation changes,
update `rotate=…` in `/boot/firmware/config.txt` and change the `--rotate`
argument in `/usr/local/bin/xdaliclock-xsession` to match:

| `config.txt` `rotate=` | xrandr `--rotate` |
|------------------------|-------------------|
| `0`                    | `normal`          |
| `90`                   | `right`           |
| `180`                  | `inverted`        |
| `270`                  | `left`            |

After editing either file, apply changes with:

```sh
sudo systemctl restart xdaliclock.service
```

## Notes

Debian packages `xdaliclock`; Debian bookworm carries `2.46-1`, while current
trixie/forky/sid carry `2.48-1`. The package description is the thing we want:
a melting digital clock.

Pimoroni's current guidance for Bullseye and later is to use the built-in
kernel overlay `vc4-kms-dpi-hyperpixel4sq`, not the legacy installer.
Raspberry Pi's overlay documentation says this overlay requires `vc4-kms-v3d`,
so the installer keeps both lines present. Raspberry Pi's overlay reference also
documents `rotate` as a HyperPixel Square overlay parameter. In testing on
kernel 6.18 with Xorg 1.21, `rotate=270` correctly orients the DRM output for
the console but is not reflected in `xrandr --query`, so the session script
applies `xrandr --output DPI-1 --rotate left` independently.

The HyperPixel backlight may remain on after shutdown; Pimoroni recommends
removing power when the display is not in use.

References checked on 2026-06-10:

- `https://shop.pimoroni.com/products/hyperpixel-4-square?variant=30138251444307`
- `https://github.com/pimoroni/hyperpixel4`
- `https://github.com/raspberrypi/rpi-imager/blob/main/src/cli.cpp`
- `https://www.raspberrypi.com/documentation/computers/getting-started.html#manual-setup-for-ssh`
- `https://www.raspberrypi.com/documentation/computers/remote-access.html#enable-the-ssh-server`
- `https://archive.raspberrypi.com/debian/pool/main/u/userconf-pi/`
- `https://sources.debian.org/src/xdaliclock/`
- `https://sources.debian.org/data/main/x/xdaliclock/2.48-1/X11/xdaliclock.man`
- `https://github.com/raspberrypi/linux/blob/rpi-6.6.y/arch/arm/boot/dts/overlays/README`
- `https://www.raspberrypi.com/documentation/computers/config_txt.html`
