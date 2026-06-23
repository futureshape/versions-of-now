# Raspberry Pi Clocks

This folder contains Linux-based clock installs for Raspberry Pi devices.
Use one subfolder per clock so the hardware assumptions, installer, and runtime
files stay close together.

Raspberry Pi clocks are different from the ESPHome clocks in this repository:
they run a full OS, use normal Linux services, and may depend on a browser,
window system, or other display stack. Keep those dependencies explicit and
avoid adding cloud, Home Assistant, MQTT, or unrelated frameworks unless a clock
actually needs them.

## Current Clocks

### Speaking Clock

- Folder: `rpi/speaking-clock/`
- Output: system audio output for a telephone handset headset or USB audio
  adapter
- Runtime: Python standard library, local text-to-speech, ALSA on Raspberry Pi,
  and `say`/`afplay` on macOS for testing

The Pi announces the local time every 10 seconds in a UK speaking-clock style
phrase and schedules the third 1 kHz stroke on the announced time. See
`speaking-clock/README.md` for installation and calibration details.

### Dali Clock on HyperPixel 4.0 Square

- Folder: `rpi/xdaliclock-hyperpixel-square/`
- Display: Pimoroni HyperPixel 4.0 Square, 720x720 DPI display
- Runtime: Raspberry Pi OS Lite with a minimal X11 session running `xdaliclock`

See `xdaliclock-hyperpixel-square/README.md` for SD-card setup and installer
details.
